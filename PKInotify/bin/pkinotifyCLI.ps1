#Monitor de caducidad de certificados y CRL's 
#Mikel V. 05/12/2016
Function send-email($smtpServer,$emailFrom,$subject,$body,$mail)
{
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$MailMessage = new-object Net.Mail.MailMessage($emailFrom, $mail, $subject, $body)
$MailMessage.IsBodyHtml = $true
$MailMessage.ReplyTo = $emailFrom
$smtp.Send($MailMessage)
} #fin send-email
Function get-cert($pkiservers,$templates,$now)
{
#$objcerts=new-object system.collections.arraylist
$objcerts=@()
foreach($pkiserver in $pkiservers)
{
	foreach($template in $templates)
	{
	$result=certutil -config "$($pkiserver.servername)\$($pkiserver.CA)" -view -restrict "Disposition=20,Certificate Template=$template,Certificate Expiration Date >= $now" -out "Request Common Name,Requester Name,Certificate Template,Certificate Effective Date,Certificate Expiration Date"
	$result|%{
		if ($_ -match "  Request Common Name: ")
		{
		$cert=""|select ca,commonname,requestername,template,notbefore,notafter
		$cert.commonname=$_ -replace ("  Request Common Name: ")
		$cert.commonname=$cert.commonname -replace('"')		
		}
		if ($_ -match "  Requester Name: ")
		{		
		$cert.requestername=$_ -replace ("  Requester Name: ")
		$cert.requestername=$cert.requestername -replace('"')		
		}
		if ($_ -match "  Certificate Template: ")
		{
		$cert.template=$_ -replace("  Certificate Template: ")
		if ($cert.template -match " "){$cert.template=$cert.template.substring($cert.template.indexof(" ")+1)}
		$cert.template=$cert.template -replace('"')		
		}
		if ($_ -match "  Certificate Effective Date: ")
		{
		$cert.notbefore=$_ -replace ("  Certificate Effective Date: ")
		$cert.notbefore=get-date($cert.notbefore)
		}
		if ($_ -match "  Certificate Expiration Date: ")
		{
		$cert.notafter=$_ -replace ("  Certificate Expiration Date: ")		
		$cert.notafter=get-date($cert.notafter)		
		$cert.ca=$pkiserver.CA
		#$objcerts.add($cert)
		$objcerts+=$cert
		}
		}#fin %
	}#fin foreach template
}#fin foreach pkiserver
return $objcerts
}
### main ###
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$database = "$scriptPath\pkinotify.s3db"
import-module "$scriptPath\SQLiteModule"
#Cargo las librerias de Mono (CRL's)
Add-Type -Path "$scriptPath\Mono.Security.dll"
#Compruebo los settings
$qry="select * from settings"
$settings=read-SQLite $database $qry
#cargo los mails
$crlmails=$cermails=@()
$qry="select * from mails where crl=1"
$mails=read-SQLite $database $qry
$crlmails+=$mails|select -expand mail
$qry="select * from mails where cer=1"
$mails=read-SQLite $database $qry
$cermails+=$mails|select -expand mail
write-host "CHECKING CRL's" -fore green
$qry="select * from cdp"
$CDPpaths=read-SQLite $database $qry
$CDPpaths|%{
$CRLfiles=get-childitem "$($_.path)\*.crl"
	foreach($CRLfile in $CRLfiles)
	{
	$CRL = [Mono.Security.X509.X509Crl]::CreateFromFile($CRLfile.fullname)
	#$daysleft=(new-timespan -start $ahora -end $CRL.NextUpdate).totaldays
	$qry="insert into crl(cdp,crl,expirationdate) values('{0}','{1}','{2:yyyy-MM-dd HH:mm:ss}')" -f $_.path,$crlfile.name,$crl.nextupdate
	try{
		write-SQLite $database $qry
		$qry
		}
	catch{
		$qry="update crl set expirationdate='{2:yyyy-MM-dd HH:mm:ss}' where crl='{1}'" -f $_.path,$crlfile.name,$crl.nextupdate
		$qry
		write-SQLite $database $qry
		}
	}
}
$qry="select *, (julianday(expirationdate) - julianday('NOW')) as days  from crl where (julianday(expirationdate) - julianday('NOW'))<{0}" -f $settings.crlwarning
$CRLs=read-SQLite $database $qry
$CRLs|%{
$subject="PKInotify: Caducidad CRL's"
$body="<html><body><p>Buenos dias,</p><p>El {0:dd/MM/yyyy} (en {3:0} dias) caduca la CRL <b>{1}</b> en {2}.</p></body></html>" -f $_.expirationdate,$_.crl,$_.cdp,$_.days
send-email $settings.smtpserver $settings.emailFrom $subject $body $($crlmails -join ",")
}
write-host "CHECKING NEW CERTIFICATES" -fore green
$qry="select * from ca"
$pkiservers=read-SQLite $database $qry
$qry="select * from templates"
$templates=read-SQLite $database $qry
$datepattern=(Get-Culture).datetimeformat.shortdatepattern
$now=get-date -format $datepattern
$objcerts=get-cert $pkiservers $($templates|select -expand id) $now
$objcerts|%{
#write-SQLite $database $qry
$qry="insert into cer(ca,commonname,template,notbefore,notafter,inuse,requestername) values('{0}','{1}','{2}','{3:yyyy-MM-dd HH:mm:ss}','{4:yyyy-MM-dd HH:mm:ss}',1,'{5}')" -f $_.ca,$_.commonname,$_.template,[datetime]$_.notbefore,[datetime]$_.notafter,$_.requestername
try{
	write-SQLite $database $qry
	$qry
	}
catch{
	#$qry="update cer set notbefore='{2:yyyy-MM-dd HH:mm:ss}' where ca='{0}' and commonname='{1}' and notafter='{3:yyyy-MM-dd HH:mm:ss}'" -f $_.ca,$_.commonname,$_.notbefore,$_.notafter
	#$qry
	#write-SQLite $database $qry
	}
}
$qry="select *, (julianday(notafter) - julianday('NOW')) as days  from cer where inuse=1 and (julianday(notafter) - julianday('NOW'))<{0}" -f $settings.cerwarning
$CERs=read-SQLite $database $qry
$CERs|%{
    $subject="PKInotify: Caducidad CER's"
    $targetmails=$cermails
    if ($_.mail.length -gt 1){$targetmails+=$_.mail}
    $body="<html><body><p>Buenos dias,</p><p>El {0:dd/MM/yyyy} (en {3:0} dias) caduca el certificado <b>{1}</b> de la entidad certificadora <b>{2}</b>.</p></body></html>" -f $_.notafter,$_.commonname,$_.ca,$_.days
    send-email $settings.smtpserver $settings.emailFrom $subject $body $($targetmails -join ",")
}
start-sleep -s 3

