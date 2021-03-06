<#
.Synopsis
  PKI Notify GUI v2. Written in Powershell + WPF with SQLite database
.DESCRIPTION
	App for managing certificate expiration mailing
.OUTPUTS
   None
.NOTES
   Author : Mikel V.
   version: 2.0
   Date   : 2020/09/21
.LINK
   http://sistemaswin.com
#>
#$VerbosePreference = "Continue"
#########################################################################
#                                Functions                             #
#########################################################################
function LoadXaml ($filename) {
	$XamlLoader = (New-Object System.Xml.XmlDocument)
	$XamlLoader.Load($filename)
	return $XamlLoader
}
function filter-grid ($text) {
	if ([bool]$text) {
		$filter = @()
		$objtext = $text -split " "
		$objtext | % { $filter += '$item -match "{0}"' -f [regex]::Escape($_) }
		$filter = $filter -join (" -and ")
		$lview.filter = { param ($item) invoke-expression $filter }
	}
	else { $lview.filter = $null }
	$lview.Refresh()
}
function listar-tabla($table, $showactive) {
	try {
		switch ($table) {
			"Certificates" {
				if (-not $DatagridCertificates.itemssource ) {
					#valor por defecto de CERWarning por si no existe setting
					$CERwarning = 20
					$qry = "select CERwarning from settings"
					read-SQLite $database $qry | % { $CERwarning = $_.cerwarning }

					if ($showactive) { $qry = "select ca,commonname,requestername,template,notafter,inuse,mail,(julianday(notafter) - julianday('NOW')) as days  from cer where inuse = 1 and ((julianday(notafter) - julianday('NOW'))>=0) order by commonname" }
					else { $qry = "select ca,commonname,requestername,template,notafter,inuse,mail,(julianday(notafter) - julianday('NOW')) as days from cer order by commonname" }
					$data = @()
					read-SQLite $database $qry | % {
						try {
							$days = [int]$_.days
							switch ($_.days) {
								( { $PSitem -lt 0 }) { $status = "expired"; break }
								( { $PSitem -le 5 }) { $status = "critical"; break }
								( { $PSitem -le $CERwarning }) { $status = "warning"; break }
								default { $status = $null }
							}
						}
						catch { $days = $status = $null }
						if ($_.inuse -eq $false) { $status = "expired" }
						$data += [pscustomobject]@{
							commonname    = $_.commonname
							requestername = $_.requestername
							template      = $_.template
							notafter      = $_.notafter
							days          = $days
							mail          = [string]$_.mail
							inuse         = $_.inuse
							ca            = $_.ca
							status        = $status
						}
					}
					$data.COUNT | OUT-HOST
					$global:lview = [System.Windows.Data.ListCollectionView]$data
					$DatagridCertificates.itemssource = $lview

				}
			}

			"CRL's" {
				if (-not $DatagridCRLs.itemssource) {
					#valor por defecto de CRLWarning por si no existe setting
					$CRLwarning = 20
					$qry = "select CRLwarning from settings"
					read-SQLite $database $qry | % { $CRLwarning = $_.crlwarning }

					$qry = "select cdp, crl, expirationdate, (julianday(expirationdate) - julianday('NOW')) as days from crl order by crl"
					$data = @()
					read-SQLite $database $qry | % {
						try {
							$days = [int]$_.days
							switch ($_.days) {
								( { $PSitem -lt 0 }) { $status = "expired"; break }
								( { $PSitem -le 5 }) { $status = "critical"; break }
								( { $PSitem -le $CRLwarning }) { $status = "warning"; break }
								default { $status = $null }
							}
						}
						catch { $days = $status = $null }
						$data += [pscustomobject]@{
							cdp            = $_.cdp
							crl            = $_.crl
							expirationdate = $_.expirationdate
							days           = $days
							status         = $status
						}
					}
					$DATA.COUNT | OUT-HOST
					$DatagridCRLs.itemssource = [System.Windows.Data.ListCollectionView]$data
				}
			}
			"CA Settings" {
				if (-not $DatagridCAs.itemssource ) {
					$qry = "select ca,servername,cdp from ca order by ca"
					$data = @()
					read-SQLite $database $qry | % {
						$data += [pscustomobject]@{
							ca         = $_.ca
							servername = $_.servername
							cdp        = $_.cdp
						}
					}
					$DATA.COUNT | OUT-HOST
					$DatagridCAs.itemssource = [System.Windows.Data.ListCollectionView]$data
				}
				if (-not $DatagridTemplates.itemssource ) {
					$qry = "select id,description from templates order by description"
					$data = @()
					read-SQLite $database $qry | % {
						$data += [pscustomobject]@{
							id          = $_.id
							description = $_.description
						}
					}
					$DATA.COUNT | OUT-HOST
					$DatagridTemplates.itemssource = [System.Windows.Data.ListCollectionView]$data
				}
			}
			"Alerting Settings" {
				if (-not $DatagridMails.itemssource) {
					$qry = "select smtpserver, emailfrom,cerwarning,crlwarning from settings"
					read-SQLite $database $qry | % {

						$SMTPServer.text = $_.SMTPServer
						$SMTPEmailFrom.text = $_.emailfrom
						$SMTPCERWarning.text = $_.cerwarning
						$SMTPCRLWarning.text = $_.crlwarning

					}

					$qry = "select mail, cer,crl from mails order by mail"
					$data = @()
					read-SQLite $database $qry | % {
						$data += [pscustomobject]@{
							mail = $_.mail
							cer  = $_.cer
							crl  = $_.crl
						}
					}
					$DATA.COUNT | OUT-HOST
					$DatagridMails.itemssource = [System.Windows.Data.ListCollectionView]$data
				}
			}

		}
	}
	catch {
		show-errormsg $_.exception.message
	}
}
function show-questionmsg($msg) {
	$overlay.visibility = "Visible"
	$buttonOK.Visibility = "Visible"
	$message.text = $msg
	$iconDialog.background = "DodgerBlue"
	$VisualBrush.RemoveAt(0)
	$VisualBrush.Add($ApplicationResources[0].Item("appbar_question"))
}

function show-errormsg($msg) {
	$overlay.Visibility = "Visible"
	$buttonOK.visibility = "Collapsed"
	$buttonCancel.focus()
	$message.text = $msg
	$iconDialog.background = "Red"
	$VisualBrush.RemoveAt(0)
	$VisualBrush.Add($ApplicationResources[0].Item("appbar_close"))
}
if (!$PSScriptRoot) { $Global:PSScriptRoot = split-path -parent $MyInvocation.MyCommand.Definition }
#########################################################################
#                        Add shared_assemblies                          #
#########################################################################
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | out-null
[System.Reflection.Assembly]::LoadFrom("$PSScriptRoot\assembly\MahApps.Metro.dll") | out-null

#########################################################################
#                        Load Main Panel                                #
#########################################################################

$database = "$PSScriptRoot\data\pkinotify.s3db"
import-module "$PSScriptRoot\SQliteModule"

"results", "logs" | % { if (!(test-path "$PSScriptRoot\$_")) { New-item -ItemType Directory -path "$PSScriptRoot\$_" | out-null } }
$logfile = "$PSscriptroot\logs\SQLiteQueries.log"

$XamlMainWindow = LoadXaml($PSScriptRoot + "\xaml\form.xaml")
$reader = (New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form = [Windows.Markup.XamlReader]::Load($reader)
$XamlMainWindow.selectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | % {
	New-Variable  -Name $_.Name -Value $Form.FindName($_.Name) -Force
}
$ApplicationResources = $Form.Resources.MergedDictionaries
$VisualBrush = $iconDialog.Child.OpacityMask.Visual.Children

#########################################################################
#                        HAMBURGER VIEWS                                #
#########################################################################

foreach ($view in gci "$PSScriptRoot\xaml\*.xaml" -exclude "Form.xaml" | select basename, fullname) {
	$XamlChildWindow = LoadXaml($view.fullname)
	$Childreader = (New-Object System.Xml.XmlNodeReader $XamlChildWindow)
	$subXaml = [Windows.Markup.XamlReader]::Load($Childreader)
	$XamlChildWindow.selectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | % {
		New-Variable  -Name $_.Name -Value $subXaml.FindName($_.Name) -Force
	}
	switch ($view.basename) {
		"Certificates" {
			$Certificates.Children.Add($subXaml) | Out-Null
		}
		"CRLs" {
			$CRLs.Children.Add($subXaml) | Out-Null
		}
		"CASettings" {
			$CASettings.Children.Add($subXaml) | Out-Null
		}
		"AlertingSettings" {
			$AlertingSettings.Children.Add($subXaml) | Out-Null
		}
		"About" {
			$About.Children.Add($subXaml) | Out-Null
		}
	}
}
#******************************************************
# Initialize with the first value of Item Section *****
#******************************************************

$HamburgerMenuControl.SelectedItem = $HamburgerMenuControl.ItemsSource[0]
listar-tabla $HamburgerMenuControl.SelectedItem.label $ShowactiveOnly.ischecked

#########################################################################
#                        HAMBURGER EVENTS                               #
#########################################################################

#******************* Items Section  *******************

$HamburgerMenuControl.add_ItemClick( {
		$HamburgerMenuControl.Content = $HamburgerMenuControl.SelectedItem
		$HamburgerMenuControl.IsPaneOpen = $false
		listar-tabla $HamburgerMenuControl.SelectedItem.label $ShowactiveOnly.ischecked

	})

#******************* Options Section  *******************

$HamburgerMenuControl.add_OptionsItemClick( {

		$HamburgerMenuControl.Content = $HamburgerMenuControl.SelectedOptionsItem
		$HamburgerMenuControl.IsPaneOpen = $false
		Switch ($HamburgerMenuControl.SelectedOptionsItem.label) {
			"About" {
				$AboutVersion.text = $null
				$qry = "select ca,timestamp from version"
				read-SQLite $database $qry | % {
					$AboutVersion.text += "{0} | Timestamp: {1:yyyy/MM/dd HH:mm} UTC`r`n" -f $_.CA, $_.timestamp
				}
			}
		}
	})

#**************** Buttons and events *****************
$ButtonBuscador.Add_Click( {
		filter-grid $TextBoxBuscador.text
	})
$TextBoxBuscador.Add_TextChanged( {
		filter-grid $TextBoxBuscador.text
	})
$Buttonexportcsv.Add_Click( {
		$resultfile = "$Psscriptroot\results\PKInotify.csv"
		$lview | export-csv -path $resultfile -notypeInformation -delimiter "`t" -encoding unicode
		start-process $resultfile

	})
$DatagridCertificates.add_CellEditEnding( {
		#si borramos este campo asumimos que queremos borrar el registro
		if ($_.Column.SortMemberPath -eq "commonname" -and $_.EditingElement.text -eq '') {
			$global:button = "ButtonDeleteCertificate"
			$global:deletecertificateCA = $_.EditingElement.DataContext.ca
			$global:deletecertificatecommonname = $_.EditingElement.DataContext.commonname
			$global:deletecertificatetemplate = $_.EditingElement.DataContext.template
			$global:deletecertificatenotafter = $_.EditingElement.DataContext.notafter
			$msg = "Please confirm deletion of {0}" -f $deletecertificatecommonname
			show-questionmsg $msg
		}
		else{
			if ($_.Column.SortMemberPath -eq "inuse") {
				$qry = "update cer set inuse={0} where ca='{1}' and commonname='{2}' and template='{3}' and notafter='{4:yyyy-MM-dd HH:mm:ss}'" -f [int]$_.EditingElement.ischecked, $_.EditingElement.DataContext.ca, $_.EditingElement.DataContext.commonname, $_.EditingElement.DataContext.template, $_.EditingElement.DataContext.notafter
			}
			elseif ($_.Column.SortMemberPath -eq "notafter") {
				$qry = "update cer set {5}='{0:yyyy-MM-dd HH:MM:ss}' where ca='{1}' and commonname='{2}' and template='{3}' and notafter='{4:yyyy-MM-dd HH:mm:ss}'" -f (get-date $_.EditingElement.text), $_.EditingElement.DataContext.ca, $_.EditingElement.DataContext.commonname, $_.EditingElement.DataContext.template, $_.EditingElement.DataContext.notafter, $_.Column.SortMemberPath
			}
			else {
				$qry = "update cer set {5}='{0}' where ca='{1}' and commonname='{2}' and template='{3}' and notafter='{4:yyyy-MM-dd HH:mm:ss}'" -f $_.EditingElement.text, $_.EditingElement.DataContext.ca, $_.EditingElement.DataContext.commonname, $_.EditingElement.DataContext.template, $_.EditingElement.DataContext.notafter, $_.Column.SortMemberPath
			}
			write-verbose -message $qry
			try {
				write-SQLite $database $qry
				'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
			}
			catch {
				'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
				show-errormsg $_.exception.message
			}
		}
	})
$expanderCertificates.Add_Expanded( {
		$NewCertificateCA.items.clear()
		$NewCertificatetemplate.items.clear()
		$qry = "select ca from ca"
		read-SQLite $database $qry | % {
			$NewCertificateCA.items.add($_.ca)
		}
		$qry = "select description from templates"
		read-SQLite $database $qry | % {
			$NewCertificatetemplate.items.add($_.description)
		}
	})
$ButtonNewCertificate.Add_Click( {
		if ([bool]$NewCertificateCA.text -and [bool]$NewCertificateName.text -and [bool]$NewCertificateTemplate.text -and [bool]$NewCertificateExpiration.text) {
			$qry = "insert into cer(ca,commonname,inuse,template,notafter,mail) values('{0}','{1}',1,'{2}','{3:yyyy-MM-dd HH:mm:ss}','{4}')" -f $NewCertificateCA.text, $NewCertificateName.text, $NewCertificateTemplate.text, (get-date $NewCertificateExpiration.text), $NewCertificateMail.text
			write-verbose -message $qry
			try {
				write-SQLite $database $qry
				'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
				$NewCertificateCA.text = $NewCertificateName.text = $NewCertificateTemplate.text = $NewCertificateExpiration.text = $NewCertificateMail.text = $null
				$DatagridCertificates.itemssource = $null
				listar-tabla "Certificates" $ShowactiveOnly.ischecked
			}
			catch {
				'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
				show-errormsg $_.exception.message
			}

		}
		else {
			show-errormsg "Fill all the fields first"
		}
	})
$showActiveOnly.Add_Click( {
		$DatagridCertificates.itemssource = $null
		listar-tabla "Certificates" $ShowactiveOnly.ischecked
	})

$DatagridCRLs.add_CellEditEnding( {
		#si borramos este campo asumimos que queremos borrar el registro
		if ($_.Column.SortMemberPath -eq "crl" -and $_.EditingElement.text -eq '') {
			$global:button = "ButtonDeleteCRL"
			$global:deleteCRL = $_.EditingElement.DataContext.CRL
			$global:deleteCDP = $_.EditingElement.DataContext.CDP
			$msg = "Please confirm deletion of {0}" -f $deleteCRL
			show-questionmsg $msg
		}
	})

$DatagridCAs.add_CellEditEnding( {
		#si borramos este campo asumimos que queremos borrar el registro
		if ($_.Column.SortMemberPath -eq "ca" -and $_.EditingElement.text -eq '') {
			$global:button = "ButtonDeleteCA"
			$global:deleteCA = $_.EditingElement.DataContext.ca
			$msg = "Please confirm deletion of {0}" -f $deleteCA
			show-questionmsg $msg
		}
		else {
			$qry = "update ca set {0}='{1}' where ca='{2}'" -f $_.Column.SortMemberPath, $_.EditingElement.text, $_.EditingElement.DataContext.ca
			write-verbose -message $qry
			try {
				write-SQLite $database $qry
				'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
			}
			catch {
				'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
				show-errormsg $_.exception.message
			}
		}
	})
$ButtonNewCA.Add_Click( {
		if ([bool]$NewCAname.text) {
			$qry = "insert into ca(ca,servername,cdp) values('{0}','{1}','{2}')" -f $NewCAname.text, $NewCAservername.text, $NewCACDP.text
			try {
				write-SQLite $database $qry
				'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
				$DatagridCAs.itemssource = $null
				listar-tabla "CA Settings"
			}
			catch {
				'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
				show-errormsg $_.exception.message
			}
		}
		else {
			show-errormsg "Fill at least CA field first"
		}
	})
$DatagridTemplates.add_CellEditEnding( {
		#si borramos este campo asumimos que queremos borrar el registro
		if ($_.EditingElement.text -eq '') {
			$global:button = "ButtonDeleteTemplate"
			$global:deleteTemplate = $_.EditingElement.DataContext.id
			$msg = "Please confirm deletion of {0}" -f $deleteTemplate
			show-questionmsg $msg
		}
		else {
			$qry = "update templates set {0}='{1}' where id='{2}'" -f $_.Column.SortMemberPath, $_.EditingElement.text, $_.EditingElement.DataContext.id
			write-verbose -message $qry
			try {
				write-SQLite $database $qry
				'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
			}
			catch {
				'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
				show-errormsg $_.exception.message
			}
		}
	})
$ButtonNewTemplate.Add_Click( {
		if ([bool]$NewTemplateid.text -and [bool]$NewTemplatedescription.text) {
			$qry = "insert into templates(id,description) values('{0}','{1}')" -f $NewTemplateid.text, $NewTemplatedescription.text
			write-verbose -message $qry
			try {
				write-SQLite $database $qry
				'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
				$DatagridTemplates.itemssource = $null
				listar-tabla "CA Settings"

			}
			catch {
				'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
				show-errormsg $_.exception.message
			}
		}
		else {
			show-errormsg "Fill all the fields first"
		}
	})
$ButtonSMTP.Add_Click( {
		$qry = "update settings set SMTPserver='{0}', emailfrom='{1}',cerwarning={2},crlwarning={3}" -f $smtpserver.text, $smtpemailfrom.text, $smtpcerwarning.text, $smtpcrlwarning.text
		write-verbose -message $qry
		try {
			write-SQLite $database $qry
			'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
		}
		catch {
			'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
			show-errormsg $_.exception.message
		}
	})
$DatagridMails.add_CellEditEnding( {
		#si borramos este campo asumimos que queremos borrar el registro
		if ($_.Column.SortMemberPath -eq "mail" -and $_.EditingElement.text -eq '') {
			$global:button = "ButtonDeleteMail"
			$global:deletemail = $_.EditingElement.DataContext.mail
			$msg = "Please confirm deletion of {0}" -f $deletemail
			show-questionmsg $msg
		}
		else {
			if ($_.Column.SortMemberPath -eq "mail") {
				$qry = "update mails set {0}='{1}' where mail='{2}'" -f $_.Column.SortMemberPath, $_.EditingElement.text, $_.EditingElement.DataContext.mail
			}
			else {
				$qry = "update mails set {0}={1} where mail='{2}'" -f $_.Column.SortMemberPath, [int]$_.EditingElement.ischecked, $_.EditingElement.DataContext.mail
			}
			write-verbose -message $qry
			try {
				write-SQLite $database $qry
				'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
			}
			catch {
				'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
				show-errormsg $_.exception.message
			}
		}
	})
$ButtonNewMail.Add_Click( {
		if ([bool]$Newmail.text) {
			$qry = "insert into mails(mail,cer,crl) values('{0}',0,0)" -f $Newmail.text
			write-verbose -message $qry
			try {
				write-SQLite $database $qry
				'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
				$DatagridMails.itemssource = $null
				listar-tabla "Alerting Settings"

			}
			catch {
				'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
				show-errormsg $_.exception.message
			}
		}
		else {
			show-errormsg "Fill email first"
		}
	})
$ButtonOK.Add_Click( {
		switch ($button) {
			"ButtonDeleteCertificate" {
				$qry = "delete from cer where ca='{0}' and commonname='{1}' and template='{2}' and notafter='{3:yyyy-MM-dd HH:mm:ss}'" -f $deletecertificateca, $deletecertificatecommonname, $deletecertificatetemplate, $deletecertificatenotafter
				write-verbose -message $qry
				try {
					write-SQLite $database $qry
					'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
					$DatagridCertificates.itemssource = $null
					listar-tabla "Certificates" $ShowactiveOnly.ischecked

				}
				catch {
					'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
					show-errormsg $_.exception.message
				}
			}
			"ButtonDeleteCRL" {
				$qry = "delete from crl where crl='{0}' and cdp='{1}'" -f $deletecrl, $deletecdp
				write-verbose -message $qry
				try {
					write-SQLite $database $qry
					'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
					$DatagridCRLs.itemssource = $null
					listar-tabla "CRL's"

				}
				catch {
					'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
					show-errormsg $_.exception.message
				}
			}
			"ButtonDeleteCA" {
				$qry = "delete from CA where ca='{0}'" -f $deleteCA
				write-verbose -message $qry
				try {
					write-SQLite $database $qry
					'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
					$DatagridCAs.itemssource = $null
					listar-tabla "CA Settings"

				}
				catch {
					'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
					show-errormsg $_.exception.message
				}
			}
			"ButtonDeleteTemplate" {
				$qry = "delete from templates where id='{0}'" -f $deletetemplate
				write-verbose -message $qry
				try {
					write-SQLite $database $qry
					'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
					$DatagridTemplates.itemssource = $null
					listar-tabla "CA Settings"

				}
				catch {
					'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
					show-errormsg $_.exception.message
				}
			}
			"ButtonDeleteMail" {
				$qry = "delete from mails where mail='{0}'" -f $deletemail
				write-verbose -message $qry
				try {
					write-SQLite $database $qry
					'{0:yyyy/MM/dd HH:mm:ss};{1};OK;{2}' -f (get-date), $env:username, $qry | out-file $logfile -append -enc unicode
					$Datagridmails.itemssource = $null
					listar-tabla "Alerting Settings"

				}
				catch {
					'{0:yyyy/MM/dd HH:mm:ss};{1};{2};{3}' -f (get-date), $env:username, $_.exception.message, $qry | out-file $logfile -append -enc unicode
					show-errormsg $_.exception.message
				}
			}

		}
		$overlay.visibility = "Hidden"
	})
$ButtonCancel.Add_Click( {
		$overlay.visibility = "Hidden"
	})

#########################################################################
#                        Show Dialog                                    #
#########################################################################

$Form.add_MouseLeftButtonDown( {
		$_.handled = $true
		$this.DragMove()
	})

$Form.ShowDialog() | Out-Null

