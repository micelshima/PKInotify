#Monitor GUI de caducidad de certificados y CRL's
#Mikel V. 10/12/2016
function SortListView ([UInt32]$Column,$ListView)
{ 
$Numeric = $true # determine how to sort
 
# if the user clicked the same column that was clicked last time, reverse its sort order. otherwise, reset for normal ascending sort
if($Script:LastColumnClicked -eq $Column)
{
    $Script:LastColumnAscending = -not $Script:LastColumnAscending
}
else
{
    $Script:LastColumnAscending = $true
}
$Script:LastColumnClicked = $Column
$ListItems = @(@(@())) # three-dimensional array; column 1 indexes the other columns, column 2 is the value to be sorted on, and column 3 is the System.Windows.Forms.ListViewItem object
 
foreach($ListItem in $ListView.Items)
{
    # if all items are numeric, can use a numeric sort
    if($Numeric -ne $false) # nothing can set this back to true, so don't process unnecessarily
    {
        try
        {
            $Test = [Double]$ListItem.SubItems[[int]$Column].Text
        }
        catch
        {
            $Numeric = $false # a non-numeric item was found, so sort will occur as a string
        }
    }
    $ListItems += ,@($ListItem.SubItems[[int]$Column].Text,$ListItem)
}
 
# create the expression that will be evaluated for sorting
$EvalExpression = {
    if($Numeric)
    { return [Double]$_[0] }
    else
    { return [String]$_[0] }
}
 
# all information is gathered; perform the sort
$ListItems = $ListItems | Sort-Object -Property @{Expression=$EvalExpression; Ascending=$Script:LastColumnAscending}
 
## the list is sorted; display it in the listview
$ListView.BeginUpdate()
$ListView.Items.Clear()
foreach($ListItem in $ListItems)
{
    $ListView.Items.Add($ListItem[1])
}
$ListView.EndUpdate()
}
Function fill-listbox($listbox)
{
$listbox.Items.clear()
$qry="select * from $($listbox.name) order by 1,2"
$rs=read-SQLite $database $qry
foreach ($r in $rs)
{
	switch($listbox.name)
	{
	"ca"{$itm = New-Object System.Windows.Forms.ListViewItem([System.String[]](@($r.ca,$r.servername)), -1)}
	"mails"{$itm = New-Object System.Windows.Forms.ListViewItem([System.String[]](@($r.mail,$r.cer,$r.crl,$r.samaccountname)), -1)}
	"cer"{
		$r=$r|select ca,commonname,requestername,template,notafter,inuse,mail,@{l='days';e={(new-timespan -start $ahora -end $r.notafter).days}}
		$itm = New-Object System.Windows.Forms.ListViewItem([System.String[]](@($r.ca,$r.commonname,$r.requestername,$r.template,$r.notafter,$r.inuse,$r.mail,$r.days)), -1)
		if([boolean]::Parse($r.inuse) -eq $false){$itm.BackColor=[System.Drawing.Color]::DarkGray}
		elseif ($r.days -lt $settings.cerwarning -and [boolean]::Parse($r.inuse) -eq $true){
			$itm.BackColor=[System.Drawing.Color]::Yellow			
			$Form1.backcolor=[System.Drawing.Color]::Crimson
			}
		
		}
	"crl"{
		$r=$r|select crl,cdp,expirationdate,@{l='days';e={(new-timespan -start $ahora -end $r.expirationdate).days}}
		$itm = New-Object System.Windows.Forms.ListViewItem([System.String[]](@($r.crl,$r.cdp,$r.expirationdate,(new-timespan -start $ahora -end $r.expirationdate).days)), -1)
		if ($r.days -lt $settings.crlwarning){
			$itm.BackColor=[System.Drawing.Color]::Yellow			
			$Form1.backcolor=[System.Drawing.Color]::Crimson
			}
		}
	"templates"{$itm = New-Object System.Windows.Forms.ListViewItem([System.String[]](@($r.id,$r.description)), -1)}
	"cdp"{$itm = New-Object System.Windows.Forms.ListViewItem([System.String[]](@($r.path,$r.description)), -1)}
	}
$listbox.Items.Addrange($itm)
}#end RS
return $rs
}
### main ###
$database = "$PSScriptRoot\pkinotify.s3db"
import-module "$PSScriptRoot\..\_Modules\SQLiteModule"
$ahora=get-date
$qry="select * from settings"
$settings=read-SQLite $database $qry
#Form
$LastColumnClicked = 0 # tracks the last column number that was clicked
$LastColumnAscending = $false # tracks the direction of the last sort of this column
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::loadwithpartialname("System.Drawing")
[System.Windows.Forms.Application]::EnableVisualStyles()
$Form1 = New-Object System.Windows.Forms.Form
$Form1.ClientSize = new-object System.Drawing.Size(910,520)
$Form1.text="SistemasWin | PKI notify GUI"
$Icon = [system.drawing.icon]::ExtractAssociatedIcon("C:\Windows\System32\certutil.exe")
$Form1.Icon = $Icon
$Form1.backcolor=[System.Drawing.Color]::Navy
$Form1.MaximizeBox = $False
$Form1.WindowState = "Normal"    # Maximized, Minimized, Normal
$Form1.SizeGripStyle = "Hide"    # Auto, Hide, Show

#header
$base64ImageString="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"
$imageBytes = [Convert]::FromBase64String($base64ImageString)
$ms = New-Object IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
$ms.Write($imageBytes, 0, $imageBytes.Length);
$logo = [System.Drawing.Image]::FromStream($ms, $true)
$pictureBox = new-object System.Windows.Forms.PictureBox
$pictureBox.Location = new-object System.Drawing.Point(620,21)
$pictureBox.Size = new-object System.Drawing.Size(278,77)
$pictureBox.TabStop = $false
$pictureBox.image=$logo
$Form1.Controls.Add($pictureBox)
#Tabs
$tabControl1 = New-Object System.Windows.Forms.TabControl
$tabControl1.DataBindings.DefaultDataSourceUpdateMode = 0
$tabControl1.Location = new-object System.Drawing.Point(5,95)
$tabControl1.Name = "tabControl1"
$tabControl1.SelectedIndex = 0
$tabControl1.ShowToolTips = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$tabControl1.Size = new-object System.Drawing.Size(($Form1.ClientSize.Width -10),($Form1.ClientSize.height -100))
$tabControl1.TabIndex = 2
$form1.Controls.Add($tabControl1)
$tabPage1 = New-Object System.Windows.Forms.TabPage
$tabPage1.Text = "CA's & CDP's"
$tabControl1.Controls.Add($tabPage1)
$tabPage2 = New-Object System.Windows.Forms.TabPage
$tabPage2.Text = "CRL"
$tabControl1.Controls.Add($tabPage2)
$tabPage2.add_doubleclick({
	$ahora=get-date
	$settings.crlwarning=$textbox7crlwarning.text
	$val=fill-listbox $listbox2
})
$tabPage3 = New-Object System.Windows.Forms.TabPage
$tabPage3.Text = "CER"
$tabControl1.Controls.Add($tabPage3)
$tabControl1.selectedtab=$tabPage3
$tabPage3.add_doubleclick({
	$ahora=get-date
	$settings.cerwarning=$textbox7cerwarning.text
	$val=fill-listbox $listbox3
})
$tabPage4 = New-Object System.Windows.Forms.TabPage
$tabPage4.Text = "Templates"
$tabControl1.Controls.Add($tabPage4)
$tabPage6 = New-Object System.Windows.Forms.TabPage
$tabPage6.Text = "Settings"
$tabControl1.Controls.Add($tabPage6)
####TAB 1 CONTENT (CA)
#textbox
$textbox1ca = New-Object System.Windows.Forms.textbox
$textbox1ca.Location = New-Object System.Drawing.Point(10,10) 
$textbox1ca.Size = new-object System.Drawing.Size(150,20)
$textbox1ca.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage1.controls.add($textbox1ca)
#textbox
$textbox1servername = New-Object System.Windows.Forms.textbox
$textbox1servername.Location = New-Object System.Drawing.Point(160,10) 
$textbox1servername.Size = new-object System.Drawing.Size(200,20)
$textbox1servername.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage1.controls.add($textbox1servername)
#button
$button1 = New-Object System.Windows.Forms.Button
$button1.Location = new-object System.Drawing.Point(850,10)
$button1.Size = new-object System.Drawing.Size(30,20)
$button1.BackColor = [System.Drawing.Color]::LightSalmon
$button1.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$button1.Font = new-object System.Drawing.Font("Webdings",13)
$button1.text="a"
$tabPage1.controls.add($button1)
$button1.Add_Click({
	$qry="insert into CA(ca,servername) values('{0}','{1}')" -f $textbox1ca.text, $textbox1servername.text
	write-SQLite $database $qry
	$val=fill-listbox $listbox1
	$textbox1ca.text=$textbox1servername.text=""
})
#listbox
$ListBox1 = New-Object System.Windows.Forms.ListView
$ListBox1.Location = New-Object System.Drawing.Point(10,40) 
$ListBox1.Size = New-Object System.Drawing.Size(($tabControl1.size.width -30),($tabControl1.size.height -280))
$ListBox1.MultiSelect = 0
$ListBox1.FullRowSelect = $true
$ListBox1.GridLines = $true
$ListBox1.view="Details"
$ListBox1.HeaderStyle="Clickable" #'none', 'Nonclickable', 'Clickable'
$ListBox1.add_ColumnClick({SortListView $_.Column $ListBox1})
$ListBox1.borderstyle = 2 #0=sin borde, 2=borde 1=hundido
#$listbox0.checkboxes = $true
#$listbox0.LabelEdit = $true
$ListBox1.name="CA"
$ListBox1.Columns.Add("ca", 150, "left")|out-null
$ListBox1.Columns.Add("servername",200, "left")|out-null
$tabPage1.Controls.Add($ListBox1)
$val=fill-listbox $listbox1
$ListBox1.add_click({
	$textbox1ca.text=$ListBox1.SelectedItems[0].SubItems[0].Text
	$textbox1servername.text=$ListBox1.SelectedItems[0].SubItems[1].Text
	})
$ListBox1.add_doubleclick({
	$textbox1ca.text=$ListBox1.SelectedItems[0].SubItems[0].Text
	$textbox1servername.text=$ListBox1.SelectedItems[0].SubItems[1].Text
	$qry="delete from ca where ca='{0}' and servername='{1}'" -f $textbox1ca.text,$textbox1servername.text
	write-sqlite $database $qry
	$val=fill-listbox $listbox1
	})
#textbox
$textbox5path = New-Object System.Windows.Forms.textbox
$textbox5path.Location = New-Object System.Drawing.Point(10,210) 
$textbox5path.Size = new-object System.Drawing.Size(300,20)
$textbox5path.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage1.controls.add($textbox5path)
#textbox
$textbox5description = New-Object System.Windows.Forms.textbox
$textbox5description.Location = New-Object System.Drawing.Point(310,210) 
$textbox5description.Size = new-object System.Drawing.Size(300,20)
$textbox5description.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage1.controls.add($textbox5description)
#button
$button5 = New-Object System.Windows.Forms.Button
$button5.Location = new-object System.Drawing.Point(850,210)
$button5.Size = new-object System.Drawing.Size(30,20)
$button5.BackColor = [System.Drawing.Color]::LightSalmon
$button5.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$button5.Font = new-object System.Drawing.Font("Webdings",13)
$button5.text="a"
$tabPage1.controls.add($button5)
$button5.Add_Click({
	$qry="insert into CDP(path,description) values('{0}','{1}')" -f $textbox5path.text,$textbox5description.text
	write-SQLite $database $qry
	$val=fill-listbox $listbox5
	$textbox5path.text=$textbox5description.text=""
})
#listbox
$ListBox5 = New-Object System.Windows.Forms.ListView
$ListBox5.name="CDP"
$ListBox5.Location = New-Object System.Drawing.Point(10,240) 
$ListBox5.Size = New-Object System.Drawing.Size(($tabControl1.size.width -30),($tabControl1.size.height -280))
$ListBox5.MultiSelect = 0
$ListBox5.FullRowSelect = $true
$ListBox5.GridLines = $true
$ListBox5.view="Details"
$ListBox5.HeaderStyle="Clickable" #'none', 'Nonclickable', 'Clickable'
$ListBox5.add_ColumnClick({SortListView $_.Column $ListBox5})
$ListBox5.Columns.Add("path", 300, "left")|out-null
$ListBox5.Columns.Add("description", 300, "left")|out-null
$ListBox5.borderstyle = 2 #0=sin borde, 2=borde 1=hundido
$tabPage1.Controls.Add($ListBox5)
$val=fill-listbox $listbox5
$ListBox5.add_click({
	$textbox5path.text=$ListBox5.SelectedItems[0].SubItems[0].Text
	$textbox5description.text=$ListBox5.SelectedItems[0].SubItems[1].Text
	})
$ListBox5.add_doubleclick({
	$textbox5path.text=$ListBox5.SelectedItems[0].SubItems[0].Text
	$textbox5description.text=$ListBox5.SelectedItems[0].SubItems[1].Text
	$qry="delete from cdp where path='{0}'" -f $textbox5path.text
	write-sqlite $database $qry
	$val=fill-listbox $listbox5
	})

####TAB 2 CONTENT (CRL)
#textbox
$textbox2crl = New-Object System.Windows.Forms.textbox
$textbox2crl.Location = New-Object System.Drawing.Point(10,10) 
$textbox2crl.Size = new-object System.Drawing.Size(200,20)
$textbox2crl.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage2.controls.add($textbox2crl)
#textbox
$textbox2cdp = New-Object System.Windows.Forms.textbox
$textbox2cdp.Location = New-Object System.Drawing.Point(210,10) 
$textbox2cdp.Size = new-object System.Drawing.Size(300,20)
$textbox2cdp.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage2.controls.add($textbox2cdp)
#textbox
$textbox2expirationdate = New-Object System.Windows.Forms.textbox
$textbox2expirationdate.Location = New-Object System.Drawing.Point(510,10) 
$textbox2expirationdate.Size = new-object System.Drawing.Size(150,20)
$textbox2expirationdate.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage2.controls.add($textbox2expirationdate)
#button
$button2 = New-Object System.Windows.Forms.Button
$button2.Location = new-object System.Drawing.Point(850,10)
$button2.Size = new-object System.Drawing.Size(30,20)
$button2.BackColor = [System.Drawing.Color]::LightSalmon
$button2.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$button2.Font = new-object System.Drawing.Font("Webdings",13)
$button2.text="a"
$tabPage2.controls.add($button2)
$button2.Add_Click({
	$qry="insert into CRL(crl,cdp,expirationdate) values('{0}','{1}','{2:yyyy-MM-dd HH:mm:ss}')" -f $textbox2crl.text, $textbox2cdp.text,[datetime]$textbox2expirationdate.text
	write-SQLite $database $qry
	$val=fill-listbox $listbox2
	$textbox2crl.text=$textbox2cdp.text=$textbox2expirationdate.text=""
})
#listbox
$ListBox2 = New-Object System.Windows.Forms.ListView
$ListBox2.Location = New-Object System.Drawing.Point(10,40) 
$ListBox2.Size = New-Object System.Drawing.Size(($tabControl1.size.width -30),($tabControl1.size.height -80))
$ListBox2.MultiSelect = 0
$ListBox2.FullRowSelect = $true
$ListBox2.GridLines = $true
$ListBox2.view="Details"
$ListBox2.HeaderStyle="Clickable" #'none', 'Nonclickable', 'Clickable'
$ListBox2.add_ColumnClick({SortListView $_.Column $ListBox2})
$ListBox2.borderstyle = 2 #0=sin borde, 2=borde 1=hundido
$ListBox2.name="CRL"
$ListBox2.Columns.Add("crl", 200, "left")|out-null
$ListBox2.Columns.Add("cdp",300, "left")|out-null
$ListBox2.Columns.Add("expiration date",150, "left")|out-null
$ListBox2.Columns.Add("days",40, "left")|out-null
$tabPage2.Controls.Add($ListBox2)
$val=fill-listbox $listbox2
$ListBox2.add_click({
	$textbox2crl.text=$ListBox2.SelectedItems[0].SubItems[0].Text
	$textbox2cdp.text=$ListBox2.SelectedItems[0].SubItems[1].Text
	$textbox2expirationdate.text=$ListBox2.SelectedItems[0].SubItems[2].Text
	})
$ListBox2.add_doubleclick({
	$textbox2crl.text=$ListBox2.SelectedItems[0].SubItems[0].Text
	$textbox2cdp.text=$ListBox2.SelectedItems[0].SubItems[1].Text
	$textbox2expirationdate.text=$ListBox2.SelectedItems[0].SubItems[2].Text
	$qry="delete from crl where crl='{0}' and cdp='{1}'" -f $textbox2crl.text,$textbox2cdp.text
	write-sqlite $database $qry
	$val=fill-listbox $listbox2
	})
####TAB 3 CONTENT (CER)
#textbox
$textbox3ca = New-Object System.Windows.Forms.textbox
$textbox3ca.Location = New-Object System.Drawing.Point(10,10) 
$textbox3ca.Size = new-object System.Drawing.Size(80,20)
$textbox3ca.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage3.controls.add($textbox3ca)
#textbox
$textbox3commonname = New-Object System.Windows.Forms.textbox
$textbox3commonname.Location = New-Object System.Drawing.Point(90,10) 
$textbox3commonname.Size = new-object System.Drawing.Size(150,20)
$textbox3commonname.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage3.controls.add($textbox3commonname)
#textbox
$textbox3requestername = New-Object System.Windows.Forms.textbox
$textbox3requestername.Location = New-Object System.Drawing.Point(240,10) 
$textbox3requestername.Size = new-object System.Drawing.Size(150,20)
$textbox3requestername.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage3.controls.add($textbox3requestername)
#textbox
$textbox3template = New-Object System.Windows.Forms.textbox
$textbox3template.Location = New-Object System.Drawing.Point(390,10) 
$textbox3template.Size = new-object System.Drawing.Size(80,20)
$textbox3template.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage3.controls.add($textbox3template)
#textbox
$textbox3notafter = New-Object System.Windows.Forms.textbox
$textbox3notafter.Location = New-Object System.Drawing.Point(470,10) 
$textbox3notafter.Size = new-object System.Drawing.Size(130,20)
$textbox3notafter.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage3.controls.add($textbox3notafter)
#combobox
$textbox3inuse = New-Object System.Windows.Forms.ComboBox 
$textbox3inuse.Location = New-Object System.Drawing.Point(600,10) 
$textbox3inuse.Size = New-Object System.Drawing.Size(50,20)
$tabPage3.Controls.Add($textbox3inuse)
$textbox3inuse.items.addrange(@("True","False"))
#textbox
$textbox3mail = New-Object System.Windows.Forms.textbox
$textbox3mail.Location = New-Object System.Drawing.Point(650,10) 
$textbox3mail.Size = new-object System.Drawing.Size(160,20)
$textbox3mail.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage3.controls.add($textbox3mail)
#button
$button3 = New-Object System.Windows.Forms.Button
$button3.Location = new-object System.Drawing.Point(850,10)
$button3.Size = new-object System.Drawing.Size(30,20)
$button3.BackColor = [System.Drawing.Color]::LightSalmon
$button3.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$button3.Font = new-object System.Drawing.Font("Webdings",13)
$button3.text="a"
$tabPage3.controls.add($button3)
$button3.Add_Click({
	$qry="insert into CER(ca,commonname,template,notafter,inuse,mail,requestername) values('{0}','{1}','{2}','{3:yyyy-MM-dd} 00:00:00','{4}','{5}','{6}')" -f $textbox3ca.text, $textbox3commonname.text, $textbox3template.text, [datetime]$textbox3notafter.text,[int][boolean]::Parse($textbox3inuse.text),$textbox3mail.text,$textbox3requestername.text
    write-SQLite $database $qry
	$val=fill-listbox $listbox3
	$textbox3ca.text=$textbox3commonname.text=$textbox3requestername.text=$textbox3template.text=$textbox3notafter.text=$textbox3inuse.text=$textbox3mail.text=""
})
#listbox
$ListBox3 = New-Object System.Windows.Forms.ListView
$ListBox3.Location = New-Object System.Drawing.Point(10,40) 
$ListBox3.Size = New-Object System.Drawing.Size(($tabControl1.size.width -30),($tabControl1.size.height -80))
$ListBox3.MultiSelect = 0
$ListBox3.FullRowSelect = $true
$ListBox3.GridLines = $true
$ListBox3.view="Details"
$ListBox3.HeaderStyle="Clickable" #'none', 'Nonclickable', 'Clickable'
$ListBox3.add_ColumnClick({SortListView $_.Column $ListBox3})
$ListBox3.borderstyle = 2 #0=sin borde, 2=borde 1=hundido
$ListBox3.name="CER"
$ListBox3.Columns.Add("ca", 80, "left")|out-null
$ListBox3.Columns.Add("common name",150, "left")|out-null
$ListBox3.Columns.Add("requester name",150, "left")|out-null
$ListBox3.Columns.Add("template",80, "left")|out-null
$ListBox3.Columns.Add("not after",130, "left")|out-null
$ListBox3.Columns.Add("in use",50, "left")|out-null
$ListBox3.Columns.Add("mail",160, "left")|out-null
$ListBox3.Columns.Add("days",40, "left")|out-null
$tabPage3.Controls.Add($ListBox3)
$val=fill-listbox $ListBox3
$ListBox3.add_click({
	$textbox3ca.text=$ListBox3.SelectedItems[0].SubItems[0].Text
	$textbox3commonname.text=$ListBox3.SelectedItems[0].SubItems[1].Text
	$textbox3requestername.text=$ListBox3.SelectedItems[0].SubItems[2].Text
	$textbox3template.text=$ListBox3.SelectedItems[0].SubItems[3].Text
	$textbox3notafter.text=$ListBox3.SelectedItems[0].SubItems[4].Text
	$textbox3inuse.text=$ListBox3.SelectedItems[0].SubItems[5].Text
	$textbox3mail.text=$ListBox3.SelectedItems[0].SubItems[6].Text
	})
$ListBox3.add_doubleclick({
	$textbox3ca.text=$ListBox3.SelectedItems[0].SubItems[0].Text
	$textbox3commonname.text=$ListBox3.SelectedItems[0].SubItems[1].Text
	$textbox3requestername.text=$ListBox3.SelectedItems[0].SubItems[2].Text
	$textbox3template.text=$ListBox3.SelectedItems[0].SubItems[3].Text
	$textbox3notafter.text=$ListBox3.SelectedItems[0].SubItems[4].Text
	$textbox3inuse.text=$ListBox3.SelectedItems[0].SubItems[5].Text
	$textbox3mail.text=$ListBox3.SelectedItems[0].SubItems[6].Text
	$qry="delete from cer where ca='{0}' and commonname='{1}' and template='{2}' and notafter='{3:yyyy-MM-dd HH:mm:ss}'" -f $textbox3ca.text,$textbox3commonname.text, $textbox3template.text, [datetime]$textbox3notafter.text
    write-sqlite $database $qry
	$val=fill-listbox $listbox3
	})
####TAB 4 CONTENT (Templates)
#textbox
$textbox4id = New-Object System.Windows.Forms.textbox
$textbox4id.Location = New-Object System.Drawing.Point(10,10) 
$textbox4id.Size = new-object System.Drawing.Size(550,20)
$textbox4id.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage4.controls.add($textbox4id)
#textbox
$textbox4description = New-Object System.Windows.Forms.textbox
$textbox4description.Location = New-Object System.Drawing.Point(560,10) 
$textbox4description.Size = new-object System.Drawing.Size(150,20)
$textbox4description.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage4.controls.add($textbox4description)
#button
$button4 = New-Object System.Windows.Forms.Button
$button4.Location = new-object System.Drawing.Point(850,10)
$button4.Size = new-object System.Drawing.Size(30,20)
$button4.BackColor = [System.Drawing.Color]::LightSalmon
$button4.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$button4.Font = new-object System.Drawing.Font("Webdings",13)
$button4.text="a"
$tabPage4.controls.add($button4)
$button4.Add_Click({
	$qry="insert into Templates(id,description) values('{0}','{1}')" -f $textbox4id.text, $textbox4description.text
	write-SQLite $database $qry
	$val=fill-listbox $listbox4
	$textbox4id.text=$textbox4description.text=""
})
#listbox
$ListBox4 = New-Object System.Windows.Forms.ListView
$ListBox4.Location = New-Object System.Drawing.Point(10,40) 
$ListBox4.Size = New-Object System.Drawing.Size(($tabControl1.size.width -30),($tabControl1.size.height -80))
$ListBox4.MultiSelect = 0
$ListBox4.FullRowSelect = $true
$ListBox4.GridLines = $true
$ListBox4.view="Details"
$ListBox4.HeaderStyle="Clickable" #'none', 'Nonclickable', 'Clickable'
$ListBox4.add_ColumnClick({SortListView $_.Column $ListBox4})
$ListBox4.borderstyle = 2 #0=sin borde, 2=borde 1=hundido
$ListBox4.name="Templates"
$ListBox4.Columns.Add("id", 550, "left")|out-null
$ListBox4.Columns.Add("description",150, "left")|out-null
$tabPage4.Controls.Add($ListBox4)
$val=fill-listbox $listbox4
$ListBox4.add_click({
	$textbox4id.text=$ListBox4.SelectedItems[0].SubItems[0].Text
	$textbox4description.text=$ListBox4.SelectedItems[0].SubItems[1].Text
	})
$ListBox4.add_doubleclick({
	$textbox4id.text=$ListBox4.SelectedItems[0].SubItems[0].Text
	$textbox4description.text=$ListBox4.SelectedItems[0].SubItems[1].Text
	$qry="delete from templates where id='{0}'" -f $textbox4id.text
	write-sqlite $database $qry
	$val=fill-listbox $listbox4
	})

####TAB 7 CONTENT (Settings)
#label
$label7smtpserver = New-Object System.Windows.Forms.Label
$label7smtpserver.Location = New-Object System.Drawing.Point(10,10) 
$label7smtpserver.Size = New-Object System.Drawing.Size(100,20)
$label7smtpserver.Text = "SMTP Server:"
$tabPage6.Controls.Add($label7smtpserver)
#textbox
$textbox7smtpserver = New-Object System.Windows.Forms.textbox
$textbox7smtpserver.Location = New-Object System.Drawing.Point(110,10) 
$textbox7smtpserver.Size = new-object System.Drawing.Size(300,20)
$textbox7smtpserver.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$textbox7smtpserver.text=$settings.smtpserver
$tabPage6.controls.add($textbox7smtpserver)
#label
$label7emailfrom = New-Object System.Windows.Forms.Label
$label7emailfrom.Location = New-Object System.Drawing.Point(10,40) 
$label7emailfrom.Size = New-Object System.Drawing.Size(100,20)
$label7emailfrom.Text = "Email from:"
$tabPage6.Controls.Add($label7emailfrom)
#textbox
$textbox7emailfrom = New-Object System.Windows.Forms.textbox
$textbox7emailfrom.Location = New-Object System.Drawing.Point(110,40) 
$textbox7emailfrom.Size = new-object System.Drawing.Size(300,20)
$textbox7emailfrom.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$textbox7emailfrom.text=$settings.emailfrom
$tabPage6.controls.add($textbox7emailfrom)
#label
$label7cerwarning = New-Object System.Windows.Forms.Label
$label7cerwarning.Location = New-Object System.Drawing.Point(10,70) 
$label7cerwarning.Size = New-Object System.Drawing.Size(100,20)
$label7cerwarning.Text = "CER Warning:"
$tabPage6.Controls.Add($label7cerwarning)
#textbox
$textbox7cerwarning = New-Object System.Windows.Forms.textbox
$textbox7cerwarning.Location = New-Object System.Drawing.Point(110,70) 
$textbox7cerwarning.Size = new-object System.Drawing.Size(40,20)
$textbox7cerwarning.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$textbox7cerwarning.text=$settings.cerwarning
$tabPage6.controls.add($textbox7cerwarning)
#label
$label7days1 = New-Object System.Windows.Forms.Label
$label7days1.Location = New-Object System.Drawing.Point(160,70) 
$label7days1.Size = New-Object System.Drawing.Size(100,20)
$label7days1.Text = "days"
$tabPage6.Controls.Add($label7days1)
#label
$label7crlwarning = New-Object System.Windows.Forms.Label
$label7crlwarning.Location = New-Object System.Drawing.Point(10,100) 
$label7crlwarning.Size = New-Object System.Drawing.Size(100,20)
$label7crlwarning.Text = "CRL Warning:"
$tabPage6.Controls.Add($label7crlwarning)
#textbox
$textbox7crlwarning = New-Object System.Windows.Forms.textbox
$textbox7crlwarning.Location = New-Object System.Drawing.Point(110,100) 
$textbox7crlwarning.Size = new-object System.Drawing.Size(40,20)
$textbox7crlwarning.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$textbox7crlwarning.text=$settings.crlwarning
$tabPage6.controls.add($textbox7crlwarning)
#label
$label7days2 = New-Object System.Windows.Forms.Label
$label7days2.Location = New-Object System.Drawing.Point(160,100) 
$label7days2.Size = New-Object System.Drawing.Size(100,20)
$label7days2.Text = "days"
$tabPage6.Controls.Add($label7days2)
#button
$button7 = New-Object System.Windows.Forms.Button
$button7.Location = new-object System.Drawing.Point(170,150)
$button7.Size = new-object System.Drawing.Size(130,20)
$button7.BackColor = [System.Drawing.Color]::LightSalmon
$button7.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$button7.text="Save"
$tabPage6.controls.add($button7)
$button7.Add_Click({
	$qry="update settings set SMTPserver='{0}', emailfrom='{1}',cerwarning={2},crlwarning={3}" -f $textbox7smtpserver.text, $textbox7emailfrom.text, $textbox7cerwarning.text, $textbox7crlwarning.text
	write-SQLite $database $qry
})
#textbox
$textbox6mail = New-Object System.Windows.Forms.textbox
$textbox6mail.Location = New-Object System.Drawing.Point(420,10) 
$textbox6mail.Size = new-object System.Drawing.Size(300,20)
$textbox6mail.borderstyle = 2 #0=sin borde, 1=borde 2=hundido
$tabPage6.controls.add($textbox6mail)
#combobox
$textbox6cer = New-Object System.Windows.Forms.ComboBox 
$textbox6cer.Location = New-Object System.Drawing.Point(720,10) 
$textbox6cer.Size = New-Object System.Drawing.Size(60,20)
$tabPage6.Controls.Add($textbox6cer)
$textbox6cer.items.addrange(@("True","False"))
#combobox
$textbox6crl = New-Object System.Windows.Forms.ComboBox 
$textbox6crl.Location = New-Object System.Drawing.Point(780,10) 
$textbox6crl.Size = New-Object System.Drawing.Size(60,20)
$tabPage6.Controls.Add($textbox6crl)
$textbox6crl.items.addrange(@("True","False"))
#button
$button6 = New-Object System.Windows.Forms.Button
$button6.Location = new-object System.Drawing.Point(850,10)
$button6.Size = new-object System.Drawing.Size(30,20)
$button6.BackColor = [System.Drawing.Color]::LightSalmon
$button6.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$button6.Font = new-object System.Drawing.Font("Webdings",13)
$button6.text="a"
$tabPage6.controls.add($button6)
$button6.Add_Click({
	$qry="insert into mails(mail, cer, crl) values('{0}','{1}','{2}')" -f $textbox6mail.text, [int][boolean]::Parse($textbox6cer.text), [int][boolean]::Parse($textbox6crl.text)
	write-SQLite $database $qry
	$val=fill-listbox $listbox6
	$textbox6mail.text=$textbox6cer.text=$textbox6crl.text=""
})
#listbox
$ListBox6 = New-Object System.Windows.Forms.ListView
$ListBox6.name="Mails"
$ListBox6.Location = New-Object System.Drawing.Point(420,40) 
$ListBox6.Size = New-Object System.Drawing.Size(($tabControl1.size.width -440),($tabControl1.size.height -80))
$ListBox6.MultiSelect = 0
$ListBox6.FullRowSelect = $true
$ListBox6.GridLines = $true
$ListBox6.view="Details"
$ListBox6.HeaderStyle="Clickable" #'none', 'Nonclickable', 'Clickable'
$ListBox6.add_ColumnClick({SortListView $_.Column $ListBox6})
$ListBox6.Columns.Add("mail", 300, "left")|out-null
$ListBox6.Columns.Add("cer", 60, "left")|out-null
$ListBox6.Columns.Add("crl", 60, "left")|out-null
$ListBox6.borderstyle = 2 #0=sin borde, 2=borde 1=hundido
$tabPage6.Controls.Add($ListBox6)
$val=fill-listbox $listbox6
$ListBox6.Add_Click({
	$textbox6mail.text=$ListBox6.SelectedItems[0].SubItems[0].Text
	$textbox6cer.text=$ListBox6.SelectedItems[0].SubItems[1].Text
	$textbox6crl.text=$ListBox6.SelectedItems[0].SubItems[2].Text
	})
$ListBox6.add_doubleclick({
	$textbox6mail.text=$ListBox6.SelectedItems[0].SubItems[0].Text
	$textbox6cer.text=$ListBox6.SelectedItems[0].SubItems[1].Text
	$textbox6crl.text=$ListBox6.SelectedItems[0].SubItems[2].Text
	$qry="delete from mails where mail='{0}'" -f $textbox6mail.text
	write-sqlite $database $qry
	$val=fill-listbox $listbox6
	})
#muestro el formulario
write-host ''
write-host '  8888888P.  888   ,888 888                   888         .d888 '
write-host '  888   d88P 888  88P"  888                   888        d88P"  '
write-host '  888    888 888 d8P    888                   888        888    '
write-host '  888  ,Y88b 88888K     888 88888Y,  ,A8888A, 888    888 888888 888  888'
write-host '  8888888K"  888 d8P    888 888 788Y 888  888 888888 888 888    888  888'
write-host '  888        888  88P,  888 888  888 888  888 888    888 888    888  888'
write-host '  888        888   888  888 888  888 888  888 788P,  888 888    Y88b 888'
write-host '  888        888    888 888 888  888 "Y8888Y"  "7888 888 888     "Y88888'
write-host '                                                                    "888'
write-host '                                                                    .888'
write-host '                                                                 8888P" '
[System.Windows.Forms.Application]::Run($Form1)