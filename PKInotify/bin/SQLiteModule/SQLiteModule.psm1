if ([Environment]::Is64BitProcess){$arch="x64"}
else{$arch="x86"}
$modulepath = split-path -parent $MyInvocation.MyCommand.Definition

#Load SQLite Library
[string]$sqlite_library_path = "$modulepath\$arch\System.Data.SQLite.dll"
[void][System.Reflection.Assembly]::LoadFrom($sqlite_library_path)

Function read-SQLite($database,$query)
{
$datatSet = New-Object System.Data.DataSet
$conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source = $database")
$dataAdapter = New-Object System.Data.SQLite.SQLiteDataAdapter($query,$conn)
[void]$dataAdapter.Fill($datatSet)
return $datatSet.Tables[0].Rows
} 
Function write-SQLite($database,$query)
{
$conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source = $database")
$conn.Open()
$command = $conn.CreateCommand()
$command.CommandText = $query
$RowsInserted = $command.ExecuteNonQuery()
$command.Dispose()
$conn.close()
}