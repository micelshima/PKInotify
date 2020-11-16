#Monitor de caducidad de certificados y CRL's
#Mikel V. 05/12/2016
param(
	[switch]$nomailing
)
Function send-email() {
param(
		[string]$mail,
		[string]$subject,
		[string]$body,
		[string]$smtpServer,
		[string]$emailFrom,
		$CC
	)
	$smtp = new-object Net.Mail.SmtpClient($smtpServer)
	$MailMessage = new-object Net.Mail.MailMessage($emailFrom, $mail, $subject, $body)
	if([bool]$CC){$CC | % { $MailMessage.cc.Add($_) }}
	$MailMessage.IsBodyHtml = $true
	$MailMessage.ReplyTo = $emailFrom
	$smtp.Send($MailMessage)
	'{0:dd/MM/yyyy HH:mm:ss}	{1}+{2}	{3}' -f (get-date), $mail, $cc,$body | out-file "$Psscriptroot\logs\pkinotify_mailing.log" -append
} #fin send-email
Function get-cert($pkiservers, $templates, $now) {
	#$objcerts=new-object system.collections.arraylist
	$objcerts = @()
	foreach ($pkiserver in $pkiservers) {
		foreach ($template in $templates) {
			out-file "$PSScriptRoot\logs\certutil_$($pkiserver.servername)_$($pkiserver.CA).txt" -input "certutil -config `"$($pkiserver.servername)\$($pkiserver.CA)`" -view -restrict `"Disposition=20,Certificate Template=$template,Certificate Expiration Date >= $now`" -out `"Request Common Name,Requester Name,Certificate Template,Certificate Effective Date,Certificate Expiration Date`""
			$result = certutil -config "$($pkiserver.servername)\$($pkiserver.CA)" -view -restrict "Disposition=20,Certificate Template=$template,Certificate Expiration Date >= $now" -out "Request Common Name,Requester Name,Certificate Template,Certificate Effective Date,Certificate Expiration Date"
			$result | out-file "$PSScriptRoot\logs\certutil_$($pkiserver.servername)_$($pkiserver.CA).txt" -append
			$result | % {
				if ($_ -match "  Request Common Name: ") {
					$cert = "" | select ca, commonname, requestername, template, notbefore, notafter
					$cert.commonname = $_ -replace ("  Request Common Name: ")
					$cert.commonname = $cert.commonname -replace ('"')
				}
				if ($_ -match "  Requester Name: ") {
					$cert.requestername = $_ -replace ("  Requester Name: ")
					$cert.requestername = $cert.requestername -replace ('"')
				}
				if ($_ -match "  Certificate Template: ") {
					$cert.template = $_ -replace ("  Certificate Template: ")
					if ($cert.template -match " ") { $cert.template = $cert.template.substring($cert.template.indexof(" ") + 1) }
					$cert.template = $cert.template -replace ('"')
				}
				if ($_ -match "  Certificate Effective Date: ") {
					$cert.notbefore = $_ -replace ("  Certificate Effective Date: ")
					$cert.notbefore = get-date $cert.notbefore
				}
				if ($_ -match "  Certificate Expiration Date: ") {
					$cert.notafter = $_ -replace ("  Certificate Expiration Date: ")
					$cert.notafter = get-date $cert.notafter
					$cert.ca = $pkiserver.CA
					#$objcerts.add($cert)
					$objcerts += $cert
				}
			}#fin %
		}#fin foreach template
	}#fin foreach pkiserver
	$objcerts | out-file "$PSScriptRoot\logs\objcerts.txt"
	return $objcerts
}
### main ###
if (!(test-path "$PSScriptRoot\logs")) { md "$PSScriptRoot\logs" | out-null }
if (test-path "$PSScriptRoot\logs\sqlite.cer.err.txt") { remove-item "$PSScriptRoot\logs\sqlite.cer.err.txt" }
$database = "$PSScriptRoot\data\pkinotify.s3db"
import-module "$PSScriptRoot\..\_Modules\SQLiteModule"
#Cargo las librerias de Mono (CRL's)
Add-Type -Path "$PSScriptRoot\assembly\Mono.Security.dll"
#Compruebo los settings
$qry = "select * from settings"
$settings = read-SQLite $database $qry
#cargo los mails
$crlmails = $cermails = @()
$qry = "select * from mails where crl=1"
$mails = read-SQLite $database $qry
$crlmails += $mails | select -expand mail
$qry = "select * from mails where cer=1"
$mails = read-SQLite $database $qry
$cermails += $mails | select -expand mail
write-host "CHECKING CRL's" -fore green
$qry = "select distinct cdp from ca"
$CDPpaths = read-SQLite $database $qry

$CDPpaths | % {
	$CRLfiles = get-childitem "$($_.cdp)\*.crl"
	foreach ($CRLfile in $CRLfiles) {
		$CRL = [Mono.Security.X509.X509Crl]::CreateFromFile($CRLfile.fullname)
		#$daysleft=(new-timespan -start $ahora -end $CRL.NextUpdate).totaldays
		$qry = "insert into crl(cdp,crl,expirationdate) values('{0}','{1}','{2:yyyy-MM-dd HH:mm:ss}')" -f $_.cdp, $crlfile.name, $crl.nextupdate
		try {
			write-SQLite $database $qry
			$qry
		}
		catch {
			$qry = "update crl set expirationdate='{2:yyyy-MM-dd HH:mm:ss}' where crl='{1}'" -f $_.cdp, $crlfile.name, $crl.nextupdate
			$qry
			write-SQLite $database $qry
		}
	}
}

if (![bool]$nomailing) {
	write-host "SENDING CRL WARNING EMAILS" -fore green
	$qry = "select *, (julianday(expirationdate) - julianday('NOW')) as days  from crl where (julianday(expirationdate) - julianday('NOW'))<{0}" -f $settings.crlwarning
	$CRLs = read-SQLite $database $qry
	$CRLs | % {
		$subject = "PKInotify: Caducidad CRL's"
		$body = "<html><body><p>Buenos dias,</p><p>El {0:dd/MM/yyyy} (en {3:0} dias) caduca la CRL <b>{1}</b> en {2}.</p></body></html>" -f $_.expirationdate, $_.crl, $_.cdp, $_.days
		send-email -mail $($crlmails -join ",") -subject $subject -body $body -SMTPServer $settings.smtpserver -EmailFrom $settings.emailFrom
	}
}
write-host "CHECKING NEW CERTIFICATES" -fore green
$qry = "select * from ca"
$pkiservers = read-SQLite $database $qry
$qry = "select * from templates"
$templates = read-SQLite $database $qry
$datepattern = (Get-Culture).datetimeformat.shortdatepattern
$now = get-date -format $datepattern
$objcerts = get-cert $pkiservers $($templates | select -expand id) $now
$objcerts | % {
	#write-SQLite $database $qry
	$qry = "insert into cer(ca,commonname,template,notbefore,notafter,inuse,requestername) values('{0}','{1}','{2}','{3:yyyy-MM-dd} 00:00:00','{4:yyyy-MM-dd} 00:00:00',1,'{5}')" -f $_.ca, $_.commonname, $_.template, [datetime]$_.notbefore, [datetime]$_.notafter, $_.requestername
	try {
		write-SQLite $database $qry
		$qry
	}
	catch {
		out-file "$PSScriptRoot\logs\sqlite.cer.err.txt" -input "$qry	$($_.exception.message)" -append
		#$qry="update cer set notbefore='{2:yyyy-MM-dd HH:mm:ss}' where ca='{0}' and commonname='{1}' and notafter='{3:yyyy-MM-dd HH:mm:ss}'" -f $_.ca,$_.commonname,$_.notbefore,$_.notafter
		#$qry
		#write-SQLite $database $qry
	}
}

if (![bool]$nomailing) {
	write-host "SENDING CER WARNING EMAILS" -fore green
	$qry = "select *, (julianday(notafter) - julianday('NOW')) as days  from cer where inuse=1 and (julianday(notafter) - julianday('NOW'))<{0} and (julianday(notafter) - julianday('NOW'))>=0" -f $settings.cerwarning
	$CERs = read-SQLite $database $qry
	$CERs | group mail | % {
		$subject = "PKInotify: Caducidad CER's"
		$body = "<html><body><p>Buenos dias,</p><p>Los siguientes certificados están proximos a caducar, si es necesario renovarlos abre un ticket en ServiceNow:</p><p><b>Catálogo de Servicios TIC > TIC > Servidores y SW Base > Gestión de Directorio Activo</b> y seleccionando <b>Certificados Internos / PKI</b> del desplegable.</p><table border='0'><tr  bgcolor='silver'><td><b>EXPIRATION DATE</b></td><td><b>DAYS LEFT</b></td><td><b>COMMON NAME</b></td><td><b>CA</b></td></tr>"
		$_.group | sort days | % { $body += "<tr><td>{0:dd/MM/yyyy}</td><td>{3:0} dias</td><td>{1}</td><td>{2}</td></tr>" -f $_.notafter, $_.commonname, $_.ca, $_.days }
		$body += "</table></body></html>"
		if ([bool]$_.values) { 
			send-email -mail $_.values -subject $subject -body $body -SMTPServer $settings.smtpserver -EmailFrom $settings.emailFrom -cc $cermails
		}
		else{
			send-email -mail $($cermails -join ",") -subject $subject -body $body -SMTPServer $settings.smtpserver -EmailFrom $settings.emailFrom
		}
	}
}
#grabo la version
foreach ($pkiserver in $pkiservers) {
	$qry = "delete from version where ca='{0}'" -f $pkiserver.ca
	write-SQLite $database $qry
	$qry = "insert into version(ca) values('{0}')" -f $pkiserver.ca
	write-SQLite $database $qry
}
