Param($Arg1 = $null)

Set-StrictMode -Version 3
<#
※ SQLの配置場所
本スクリプトと同じディレクトリにsqlフォルダを作成し、
そのフォルダにSQLを配置してください
　SQLは、接続先毎に使い分けるようになっています。
　sqlフォルダ直下に接続先名のフォルダを作成し、その中に各接続先用のSQLを保存してください。
　（フォルダは接続先名のフォルダを含め、２階層まで対応）

※ サーバーへの接続方法について
　セキュリティ上の観点から、ソース内に接続文字列を記載せず、
　接続先名のフォルダ直下にconnect.udlを配置してください。
#>

Add-Type -AssemblyName PresentationFramework  # WPF用

[System.Data.SqlClient.SqlConnection]$objConnection	= $null;
[System.Data.SqlClient.SqlCommand]$objCommand		= $null;
[System.Data.SqlClient.SqlDataAdapter]$objAdapter	= $null;
[System.Data.DataSet]$objDataset = $null;
 
[string]$SqlRootDir = $PSScriptRoot + "\sql"

# 設定ファイルのデフォルト値
$CONF=@{
	WindowHeight=500
	WindowWidth=950
	DataGridMaxColumnWidth=500
	DataGridMinRowHeight=30
	TextDecorationPrefix="text_decoration_"
	TextDecorationSuffix="_bindingText"
	StartProcessPrefix="start_process_"
	Typeface="メイリオ"
	IconText="🛠"
	AppName="TwoThree"
	Debug=$false
	Verbose=$false
}
# 設定ファイル読み込み
$INI_PATH = [System.IO.Path]::GetFullPath("$PSScriptRoot\config.ini")
if(Test-Path $INI_PATH) {
	Get-Content -Encoding UTF8 $INI_PATH | ConvertFrom-StringData | ForEach-Object {
		$hashTable = $_
		$hashTable.Keys | ForEach-Object {
			$CONF[$_] = $hashTable[$_]
		}
	}
}

if($CONF.Debug) {
	$DebugPreference = "Continue"
}
if($CONF.Verbose) {
	$VerbosePreference = "Continue"
}

<# XAML にて Window 構築 #>
[xml]$MainXAML = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="{Binding Title, Mode=OneWay, UpdateSourceTrigger=PropertyChanged}" Height="$($CONF.WindowHeight)" Width="$($CONF.WindowWidth)">

	<Window.Resources>
		<Style TargetType="DataGrid">
			<Setter Property="MaxColumnWidth" Value="$($CONF.DataGridMaxColumnWidth)" />
			<Setter Property="MinRowHeight" Value="$($CONF.DataGridMinRowHeight)" />
			<Setter Property="SelectionUnit" Value="2" />
			<Setter Property="HeadersVisibility" Value="All" />
		</Style>
		<Style TargetType="DataGridRowHeader">
			<Setter Property="Width" Value="20" />
		</Style>
	</Window.Resources>

	<TabControl x:Name="TabChildContainer" Height="Auto" Width="Auto" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" >
		<TabItem Header="未選択" />
		<TabItem Header="+" />
	</TabControl>

	<Window.TaskbarItemInfo>
		 <TaskbarItemInfo x:Name="TaskbarItemInfo" ThumbnailClipMargin="0,0,$($CONF.WindowWidth - 350),$($CONF.WindowHeight - 200)" />
	</Window.TaskbarItemInfo>
	
</Window>
"@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.XML.XmlNodeReader $MainXAML))

function createTabItem {
	
	$TabItem = New-Object System.Windows.Controls.TabItem -Property @{
		Header="未選択"
	}
	
	$TabItem.add_MouseDown({
		$Script:ClickedTab = $this
	})
	$TabItem.ToolTip = "未選択"

	[xml]$TabContentXAML = @"
<DockPanel
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

	<StackPanel DockPanel.Dock="Top" Orientation="Vertical" x:Name="TabContent">
		<WrapPanel Orientation="Horizontal" Height="23">
			<Label>SERVER:</Label>
			<ComboBox x:Name="serverComboBox"
				ItemsSource="{Binding ServerItems, Mode=OneWay}" />
			<Button x:Name="FolderButton" Margin="15,0,0,0" ToolTip="SQLのフォルダを開く">Folder</Button>
			<Button x:Name="FileButton" Margin="5,0,0,0" ToolTip="SQLを開く">File</Button>
			<CheckBox x:Name="ClipCheckBox" Margin="5,3,3,0" ToolTip="実行するSQLをクリップボードにコピー" ></CheckBox>
			<Label x:Name="resultLabel"></Label>
		</WrapPanel>

		<WrapPanel Orientation="Horizontal" Height="23">
			<Label>SQL:</Label>
			<ComboBox x:Name="sqlComboBox1"
				ItemsSource="{Binding SqlItems1, Mode=OneWay, UpdateSourceTrigger=PropertyChanged}" />
			<WrapPanel Orientation="Horizontal" Height="23" x:Name="sqlSubPanel" >
				<Label>＞</Label>
				<ComboBox x:Name="sqlComboBox2"
					ItemsSource="{Binding SqlItems2, Mode=OneWay, UpdateSourceTrigger=PropertyChanged}" />
			</WrapPanel>
		</WrapPanel>

		<Separator/>

		<WrapPanel x:Name="InputPanel" Orientation="Horizontal" />
			
	</StackPanel>

	<Separator/>

	<DataGrid x:Name="DataGrid"
		EnableColumnVirtualization="True" 
		EnableRowVirtualization="True" 
		VirtualizingPanel.IsVirtualizing="True" 
		VirtualizingPanel.VirtualizationMode="Recycling" 
		AutoGenerateColumns="False"
		CanUserAddRows="False"
		CanUserDeleteRows="False"
		HorizontalScrollBarVisibility="Visible"
		VerticalScrollBarVisibility="Visible"
		IsReadOnly="True"
		/>
</DockPanel>
"@

	$TabContent= [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $TabContentXAML))

	$TabContent.DataContext = [PSCustomObject]@{
		ServerItems = @(Get-ChildItem -Filter * -Path $Script:SqlRootDir | Where-Object {$_.PSIsContainer})
		SqlItems1 = $null
		SqlItems2 = $null
		strSQL = ""
	}
	
	$TabContent.findName("serverComboBox").add_SelectionChanged({
		if($this.SelectedIndex -ne -1) {
			Write-Debug " serverComboBox_SelectionChanged"

			$t = @()
			@(Get-ChildItem -Filter * -Path ($SqlRootDir + "/" + $this.parent.findName("serverComboBox").SelectedItem)) | Where-Object { $_.Name -like "*.sql" -or $_.Attributes -match'Directory' } | ForEach-Object {
				if ($_.PSIsContainer) {
					$t += "├" + $_.Name
				} else {
					$t += $_.Name
				}
			}
			$this.DataContext.SqlItems1 = $t
			$this.DataContext.SqlItems2 = $null
		} else {
			$this.DataContext.SqlItems1 = $null
			$this.DataContext.SqlItems2 = $null
		}
		updateDataContext $this.parent.parent
	})
	
	$TabContent.findName("sqlComboBox1").add_SelectionChanged({
		if($this.SelectedIndex -ne -1) {
			Write-Debug " sqlComboBox1_SelectionChanged"
			if($this.parent.findName("sqlComboBox1").SelectedItem -match("├")) {
				$this.DataContext.SqlItems2 = @(Get-ChildItem -Filter *.sql -Path ($SqlRootDir + "/" + $this.parent.findName("serverComboBox").SelectedItem + "/" + ($this.parent.findName("sqlComboBox1").SelectedItem.Replace("├",""))))
			} else {
				$this.DataContext.SqlItems2 = $null
			}
		} else {
			$this.DataContext.SqlItems2 = $null
		}
		updateDataContext $this.parent.parent
	})
	
	$TabContent.findName("sqlComboBox2").add_SelectionChanged({
		if($this.SelectedIndex -ne -1) {
			Write-Debug " sqlComboBox2_SelectionChanged"
		}
		updateComboBox $this.parent.parent
	})

	$TabContent.findName("FolderButton").add_Click({
		$Content = $this.parent.parent
		$serverCombo = $Content.findName("serverComboBox")
		$sqlCombo1 = $Content.findName("sqlComboBox1")
		$sqlCombo2 = $Content.findName("sqlComboBox2")

		if($sqlCombo2.Items.Count -eq 0) {
			Invoke-Item ($SqlRootDir, $serverCombo.SelectedItem -join "\")
		} else {
			Invoke-Item ($SqlRootDir, $serverCombo.SelectedItem, $sqlCombo1.SelectedItem.Replace("├","") -join "\")
		}
	})
	
	$TabContent.findName("FileButton").add_Click({
		$Content = $this.parent.parent
		$serverCombo = $Content.findName("serverComboBox")
		$sqlCombo1 = $Content.findName("sqlComboBox1")
		$sqlCombo2 = $Content.findName("sqlComboBox2")

		if($sqlCombo2.Items.Count -eq 0) {
			Invoke-Item ($SqlRootDir, $serverCombo.SelectedItem, $sqlCombo1.SelectedItem -join "\")
		} else {
			Invoke-Item ($SqlRootDir, $serverCombo.SelectedItem, $sqlCombo1.SelectedItem.Replace("├",""), $sqlCombo2.SelectedItem -join "\")
		}
	})

	$TabItem.AddChild($TabContent)

	$DataGrid = $TabContent.findName("DataGrid")
	
	$DataGrid.add_MouseDoubleClick({
#		Write-Host "MouseDoubleClick"
		
		$this.ItemsSource[$this.Items.IndexOf($this.CurrentItem)].psobject.properties.name | ForEach-Object {
			
			if(("_" + $_ + "_") -notmatch ("_" + $this.SelectedCells.Column.Header + "_")) {
				#部分一致しなければスキップ
			} elseif($_ -match "$($CONF.TextDecorationPrefix)") {
				if($_ -match "$($CONF.TextDecorationSuffix)") {
					Set-Clipboard $this.SelectedCells[0].Item.("$($CONF.TextDecorationPrefix)" + $this.SelectedCells.Column.Header + "$($CONF.TextDecorationSuffix)")
				}
			} elseif($_ -match "$($CONF.StartProcessPrefix)") {
			if($_ -eq "$($CONF.StartProcessPrefix)" + $this.SelectedCells.Column.Header) {
				Start-Process $this.SelectedCells[0].Item.("$($CONF.StartProcessPrefix)" + $this.SelectedCells.Column.Header)
			}
			} else {
				Set-Clipboard $this.SelectedCells[0].Item.($this.SelectedCells.Column.Header)
			}
		}
		
	})

	return $TabItem
}


$tabContainer = $window.findName("TabChildContainer")

$ContextMenu = New-Object System.Windows.Controls.ContextMenu
$MenuItem = New-Object System.Windows.Controls.MenuItem -Property @{
	Header="閉じる"
}
$ContextMenu.AddChild($MenuItem)

$MenuItem.add_Click({
	if($tabContainer.Items.Count -gt 2) {
		
		$index = $tabContainer.SelectedIndex
		$count = $tabContainer.Items.Count

		if($index -eq ($count - 2)) {
			$tabContainer.SelectedIndex = $index -1
		}
		$tabContainer.Items.Remove($Script:ClickedTab)
	} else {
		$tabContainer.Items.Remove($Script:ClickedTab)
		
		$window.Close()
	}
})

$tabContainer.ContextMenu = $ContextMenu

$tabContainer.add_ContextMenuOpening({
	if($null -ne $_.OriginalSource.parent) {
		$_.Handled = $true
	}
})

$tabContainer.add_SelectionChanged({
	$index = $tabContainer.SelectedIndex
	$count = $tabContainer.Items.Count

	if($index -eq ($count - 1)) {
		addNewTab
	}
	
	$window.DataContext = [PSCustomObject]@{
		Title = "$($window.findName("TabChildContainer").SelectedItem.Header) - $($CONF.AppName) $((Get-ItemProperty $PSCommandPath).LastWriteTime.ToString("yyyy/MM/dd") + "版")"
	}
})

function addNewTab {

	Write-Debug "addNewTab"

	$count = $tabContainer.Items.Count
	$tabItem = createTabItem
	$tabContainer.Items.Insert($count -1, $tabItem)
	$tabContainer.SelectedIndex = $count -1
}

function addInputButton {
	Param($Content, $param)
	$newPanel = New-Object System.Windows.Controls.StackPanel -Property @{
		Orientation="Horizontal"
	}

	$subItem1 = New-Object System.Windows.Controls.Button -Property @{
		Content=$param
		Margin="0,0,10,0"
	}

	$subItem1.add_Click({
		initDataGrid $this.parent.parent.findName("DataGrid") (updateGrid $this)
		$this.parent.parent.findName("resultLabel").Content = '{0} 件' -f $this.parent.parent.findName("DataGrid").ItemsSource.Count

		$this.parent.parent.findName("DataGrid").Columns | ForEach-Object {
			$style = New-Object System.Windows.Style([System.Windows.Controls.TextBlock])
			$style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::TextWrappingProperty, [System.Windows.TextWrapping]::Wrap)))
			if($_.psobject.properties.match('ElementStyle').Count) {
				$_.ElementStyle = $style
			}
		}
	})
	
	$newPanel.AddChild($subItem1)
	$Content.findName("InputPanel").AddChild($newPanel)
}

function addComboBox {
	Param($Content, $param, $ValueSets)

	$ValueSetArray = $ValueSets.Split(",")

	$DataSource = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
	foreach($ValueSet in $ValueSetArray) {
		$DataSource.Add([PSCustomObject]@{Value = $ValueSet.Split(":")[0];Display = $ValueSet.Split(":")[1]})
	}

	$newPanel = New-Object System.Windows.Controls.StackPanel -Property @{
		Orientation="Horizontal"
	}

	$subItem1 = New-Object System.Windows.Controls.Label -Property @{
		Content = $param + "："
	}
	
	$subItem2 = New-Object System.Windows.Controls.ComboBox -Property @{
		DisplayMemberPath = 'Display'
		SelectedValuePath = 'Value'
		ItemsSource = $DataSource
		Margin="0,0,10,0"
	}
	$subItem2.SelectedIndex = 0

	$newPanel.AddChild($subItem1)
	$newPanel.AddChild($subItem2)

	$Content.findName("InputPanel").AddChild($newPanel)
}

function addTextBox {
	Param($Content, $param)
	
	$newPanel = New-Object System.Windows.Controls.StackPanel -Property @{
		Orientation="Horizontal"
	}

	$subItem1 = New-Object System.Windows.Controls.Label -Property @{
		Content = $param + "："
	}
	
	$subItem2 = New-Object System.Windows.Controls.TextBox -Property @{
		Text = ""
		Width = 120
		Margin="0,0,10,0"
	}
	
	$subItem1.Add_MouseDown({
		$sender, $e = $this, $_
		$sender.parent.Children[1].Text = (Get-Clipboard).Trim()
		$sender.parent.Children[1].Focus()
	})

	# キーボードイベントの処理
	$subItem2.Add_KeyDown({
		$sender, $e = $this, $_
		
		# Enterキー
		if($_.key -eq "Return") {
			$sender.Text = $sender.Text.Trim()
			initDataGrid $this.parent.parent.findName("DataGrid") (updateGrid $this)
			$sender.parent.parent.findName("resultLabel").Content = '{0} 件' -f $sender.parent.parent.findName("DataGrid").ItemsSource.Count
			
			$sender.parent.parent.findName("DataGrid").Columns | ForEach-Object {
				$style = New-Object System.Windows.Style([System.Windows.Controls.TextBlock])
				$style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::TextWrappingProperty, [System.Windows.TextWrapping]::Wrap)))
				if($_.psobject.properties.match('ElementStyle').Count) {
					$_.ElementStyle = $style
				}
			}
		}

		# Escキー
		if($_.key -eq "Escape") {
			$sender.Text = ""
			$sender.parent.parent.findName("DataGrid").ItemsSource = $null
			$sender.parent.parent.findName("resultLabel").Content = ''
		}
		
		# Ctrl + A
		if($_.key -eq "A") {
			if("Modifiers" -in $_.PSobject.Properties.Name) {
				if($_.Modifiers -eq "Control") {
					$sender.SelectAll()
				}
			}
		}
		
	})

	$newPanel.AddChild($subItem1)
	$newPanel.AddChild($subItem2)

	$Content.findName("InputPanel").AddChild($newPanel)
}

function initInputPanel {
	Param($Content, $params = $null)
	Write-Debug "initInputPanel"

	$Content.findName("InputPanel").Children.Clear()
	
	if(($null -eq $params) -or ($params.Count -eq 0)) {
		addInputButton $Content "実行"
	} else {
		foreach($key in $params.Keys) {
			
			if($params[$key] -eq "") {
				addTextBox $Content $key
			} elseif($null -eq $params[$key]) {
				addTextBox $Content $key
			} else {
				addComboBox $Content $key $params[$key]
			}
		}
		addInputButton $Content "検索"
	}
}
function updateDataContext {
	Param($Content)
	Write-Debug "updateDataContext"

	$Content.DataContext = [PSCustomObject]@{
		ServerItems = $Content.DataContext.ServerItems
		SqlItems1 = $Content.DataContext.SqlItems1
		SqlItems2 = $Content.DataContext.SqlItems2
		strSQL =  $Content.DataContext.strSQL
	}
	
	updateComboBox $Content
}

function updateComboBox {
	Param($Content)
	Write-Debug "updateComboBox"
	
	$Content.findName("InputPanel").Children.Clear()
	
	$Content.findName("DataGrid").ItemsSource = $null
	$Content.findName("DataGrid").Columns.Clear()

	$window.findName("TabChildContainer").SelectedItem.Header = "未選択"

	$window.DataContext = [PSCustomObject]@{
		Title = "$($window.findName("TabChildContainer").SelectedItem.Header) - $($CONF.AppName) $((Get-ItemProperty $PSCommandPath).LastWriteTime.ToString("yyyy/MM/dd") + "版")"
	}

	$serverCombo = $Content.findName("serverComboBox")
	if($serverCombo.Items.Count -eq 1 -and $null -eq $serverCombo.SelectedItem) {
		Write-Debug ("　" + $serverCombo.Items[0].ToString() + "を選択しました")
		$serverCombo.SelectedIndex = 0
		return
	} elseif($serverCombo.Items.Count -eq 0) {
		Write-Debug ("serverComboをリセットしました")
		$serverCombo.SelectedIndex = $null
		return
	}
	
	$sqlCombo1 = $Content.findName("sqlComboBox1")
	if($sqlCombo1.Items.Count -eq 1 -and $null -eq $sqlCombo1.SelectedItem) {
		Write-Debug ("　" + $sqlCombo1.Items[0].ToString() + "を選択しました")
		$sqlCombo1.SelectedIndex = 0
		return
	} elseif($sqlCombo1.Items.Count -eq 0) {
		Write-Debug ("sqlCombo1をリセットしました")
		$sqlCombo1.SelectedIndex = $null
		return
	}

	$sqlCombo2 = $Content.findName("sqlComboBox2")
	if($sqlCombo2.Items.Count -gt 0) {
		$Content.findName("sqlSubPanel").Visibility = [System.Windows.Visibility]::Visible
		if($sqlCombo1.Items.Count -eq 1 -and $null -eq $sqlCombo2.SelectedItem) {
			Write-Debug ("　" + $sqlCombo2.Items[0].ToString() + "を選択しました")
			$sqlCombo2.SelectedIndex = 0
		}
	} else {
		if($Content.findName("sqlSubPanel").Visibility -ne [System.Windows.Visibility]::Hidden) {
			$Content.findName("sqlSubPanel").Visibility = [System.Windows.Visibility]::Hidden
		}
	}

	if($sqlCombo2.Items.Count -eq 0) {
		if($serverCombo.SelectedIndex -ge 0 -and $sqlCombo1.SelectedIndex -ge 0) {
			openSql $Content ($SqlRootDir, $serverCombo.SelectedItem, $sqlCombo1.SelectedItem -join "\")
		}
	} else {
		if($serverCombo.SelectedIndex -ge 0 -and $sqlCombo1.SelectedIndex -ge 0 -and $sqlCombo2.SelectedIndex -ge 0) {
			openSql $Content ($SqlRootDir, $serverCombo.SelectedItem, $sqlCombo1.SelectedItem.Replace("├",""), $sqlCombo2.SelectedItem -join "\")
		}
	}
}


function openSql {
	Param($Content, $sqlFullPath)

	Write-Debug (" openSql " + $sqlFullPath)
	
	$tabContainer = $window.findName("TabChildContainer")
	$tabContainer.SelectedItem.ToolTip = $sqlFullPath

	$window.findName("TabChildContainer").SelectedItem.Header = (Split-Path $sqlFullPath -Leaf)

	$window.DataContext = [PSCustomObject]@{
		Title = "$($window.findName("TabChildContainer").SelectedItem.Header) - $($CONF.AppName) $((Get-ItemProperty $PSCommandPath).LastWriteTime.ToString("yyyy/MM/dd") + "版")"
	}

	$params = [ordered]@{}
	
	if(Test-Path $sqlFullPath) {
		#ファイルが存在する場合はこちらが実行されます。
		#[System.Windows.Forms.MessageBox]::Show("ファイルは存在します。")
	} else {
		#ファイルが存在しない場合はこちらが実行されます。
		Write-Host $sqlFullPath + "　が見つかりません"
#		[System.Windows.Forms.MessageBox]::Show("ファイルが存在しません(sql)。")
		$form = New-Object System.Windows.Window
		$form.ShowDialog()
		exit 1
	}
	
	$Content.DataContext.strSQL = ""

	$paramList = ""
	$paramArr = ""
	$paramArrIgnore = ""
	$paramLengthList = ""

	#変数の情報を取得
	$file = New-Object System.IO.StreamReader($sqlFullPath, [System.Text.Encoding]::GetEncoding("sjis"))
	while ($null -ne ($line = $file.ReadLine()))
	{
		#変数のデフォルト値検出用（変数の定義が複数行だった場合のエラー対策）
		$line = [regex]::Replace($line, "^SET\s+@[^']+'[^']*$", " declare @garbage varchar(1);set @garbage ='", "Ignorecase")

		#変数セット検出用（削除します）
		$line = [regex]::Replace($line, "^SET\s+@.+", "", "Ignorecase")

		#変数定義検出用
		$sqlParam = [regex]::Matches($line, "^DECLARE\D+@([^ ]+)[^\d]+(\d+)(.+)", "Ignorecase")
		$line = [regex]::Replace($line, "^DECLARE\D+@([^ ]+)[^\d]+(\d+)(.+)", "", "Ignorecase")

		if($sqlParam.Count -gt 0) {
			$sqlParam2 = [regex]::Matches($sqlParam.Captures.Groups[3].Value, "/\* (.+) \*/")

			$paramList = $paramList + $sqlParam.Captures.Groups[1].Value + ","
			$paramLengthList = $paramLengthList + $sqlParam.Captures.Groups[2].Value + ","
			
			if($sqlParam2.Count -gt 0) {
				if([regex]::Matches($sqlParam2.Captures.Groups[1].Value, ":.+,.+:")) {
					$paramArr = $paramArr + $sqlParam2.Captures.Groups[1].Value + "\\"
					$paramArrIgnore = $paramArrIgnore + "\\"
				} else {
					$paramArr = $paramArr + "\\"
					$paramArrIgnore = $paramArrIgnore + $sqlParam.Captures.Groups[0].Value + "\\"
				}
			} else {
				$paramArr = $paramArr + "\\"
				$paramArrIgnore = $paramArrIgnore + $sqlParam.Captures.Groups[0].Value + "\\"
				$paramArrIgnore = $paramArrIgnore + "\\"
			}
			
		}

		$Content.DataContext.strSQL = $Content.DataContext.strSQL + $line + "`r`n"
	}

	$file.Close()
	
	if ($paramList -ne "") {
		$paramList = $paramList.Replace(","," ")
		$paramList = $paramList.TrimEnd()
		$paramListArr = $paramList.Split(" ")

		if ($paramArr -ne "") {
			$paramArr = $paramArr.Replace(" ","")
			$paramArr = $paramArr.Replace("\\"," ")
#			$paramArr = $paramArr.TrimEnd()
			$paramArrArr = $paramArr.Split(" ")
		}
		
		if ($paramArrIgnore -ne "") {
			$paramArrIgnore = $paramArrIgnore.Replace(" ","")
			$paramArrIgnore = $paramArrIgnore.Replace("\\"," ")
			$paramArrIgnore = $paramArrIgnore.TrimEnd()
		}
		
		$paramLengthList = $paramLengthList.Replace(","," ")
		$paramLengthList = $paramLengthList.TrimEnd()

		for ($i=0; $i -lt $paramListArr.Count; $i++){
			if ($paramArrArr[$i] -ne "") {#ComboBox
				$params.Add($paramListArr[$i], $paramArrArr[$i])
			} else {#TextBox
				$params.Add($paramListArr[$i], "")
			}
		}
	}
	
	initInputPanel $Content $params
	$Content.findName("DataGrid").ItemsSource = $null
	$Content.findName("resultLabel").Content = ''
}

function updateGrid {
	Param($Content)
	
	$serverCombo = $Content.findName("serverComboBox")

	#udlファイルがあればSQL実行。なければフォームの内容を表示
	if(Test-Path (Join-Path ($SqlRootDir, $serverCombo.SelectedItem -join "\") "connect.udl")) {
		Write-Debug "connect.udl found"
		return execQuery $Content
	} else {
		Write-Host "connect.udl not found"
		return execQueryTest $Content
	}
}

function execQuery {
	Param($Content)
	
	Write-Debug "execQuery"
	# 実行するSQL
	$tmpSQL = $Content.DataContext.strSQL
#   フォームの内容を格納する変数
	$params = @{}

	$Content.findName("InputPanel").Children | ForEach-Object {
		if($_.Children[0].GetType() -eq [System.Windows.Controls.Label]) {
			if($_.Children[1].GetType() -eq [System.Windows.Controls.TextBox]) {
				$params.Add($_.Children[0].Content.Replace("：",""),$_.Children[1].Text)
			}
			if($_.Children[1].GetType() -eq [System.Windows.Controls.ComboBox]) {
				$params.Add($_.Children[0].Content.Replace("：",""),$_.Children[1].SelectedItem.Value)
			}
		}
	}

	#SQLの変数を値に置換
	foreach($key in $params.Keys) {
		if($params[$key] -eq "") {
			$val = "'%'"
		} elseif($null -eq $params[$key]) {
			$val = "'%'"
		} else {
			$val = "'" + $params[$key] + "'"
		}

		$tmpSQL = [regex]::Replace($tmpSQL, "@" + $key, $val)
	}
	
	$serverCombo = $Content.findName("serverComboBox")
	# 接続文字列を作成
	if(Test-Path (Join-Path ($SqlRootDir, $serverCombo.SelectedItem -join "\") "connect.udl")) {
		$strConnectionString = ''
		
		$file = New-Object System.IO.StreamReader((Join-Path ($SqlRootDir, $serverCombo.SelectedItem -join "\") "connect.udl"), [System.Text.Encoding]::GetEncoding("unicode"))
		while ($null -ne ($line = $file.ReadLine()))
		{
			if($line -match '^\[.+') {
			} elseif($line -match '^;.+') {
			} else {
				$line = [regex]::Replace($line, "Provider=[^;]+;", "", "Ignorecase")#不要なパラメータ削除
				$strConnectionString = $strConnectionString + $line + "`r`n"
			}
		}
			
		$file.Close()
	} else {
		# 接続文字列を作成
		$strConnectionString = @"
Data Source=;
Initial Catalog=;
User ID=;
"@ 
	}

	$objConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection;
	$objConnection.ConnectionString = $strConnectionString;
	$objCommand = $objConnection.CreateCommand();
	$objCommand.CommandText = $tmpSQL;
	
	$objAdapter = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter $objCommand;
	$objDataset = New-Object -TypeName System.Data.DataSet;

	#SQLをクリップボードにコピー
	if($Content.findName("ClipCheckBox").IsChecked -eq $true) {
		Set-Clipboard $tmpSQL
	}
	
	[void]$objAdapter.Fill($objDataset);
	
	# DataSetにセットされた1個目のテーブルを取り出す
	$DT = $objDataset.Tables[0];

	return ,$DT
}

#ダミーデータ作成
function execQueryTest {
	Param($Content)

	Write-Debug "execQueryTest"
	
#   フォームの内容を格納する変数
	$params = [ordered]@{}

	$Content.findName("InputPanel").Children | ForEach-Object {
		if($_.Children[0].GetType() -eq [System.Windows.Controls.Label]) {
			if($_.Children[1].GetType() -eq [System.Windows.Controls.TextBox]) {
				$params.Add($_.Children[0].Content.Replace("：",""),$_.Children[1].Text)
			}
			if($_.Children[1].GetType() -eq [System.Windows.Controls.ComboBox]) {
				$params.Add($_.Children[0].Content.Replace("：",""),$_.Children[1].SelectedItem.Value)
			}
		}
	}

	#ハッシュテーブルをクリップボードにコピー
	if($Content.findName("ClipCheckBox").IsChecked -eq $true) {
		Set-Clipboard ( $params.Keys | ForEach-Object { $_ + " : " + $params[$_] + ";" })
	}

	$DT = New-Object System.Data.DataTable
	[void]$DT.Columns.Add("Param")
	[void]$DT.Columns.Add("ValueSets")
	
	#SQLの変数を値に置換
	foreach($key in $params.Keys) {
		$Row = $DT.NewRow()
		$Row["Param"] = $key
		if($params[$key] -eq "") {
			$Row["ValueSets"] = ""
		} elseif($null -eq $params[$key]) {
			$Row["ValueSets"] = ""
		} else {
			$Row["ValueSets"] = $params[$key]
		}
		[void]$DT.Rows.Add($Row)
	}

	return ,$DT
}

function trySelectCombo {
	Param($sqlFullPath)
	Write-Debug (" trySelectCombo " + $sqlFullPath)

	$tabContainer = $window.findName("TabChildContainer")
	$tabContainer.SelectedItem.ToolTip = $sqlFullPath

	$dispatcherTimer = [System.Windows.Threading.DispatcherTimer]::new()
	$dispatcherTimer.Interval = [timespan]::FromSeconds(1)
	$dispatcherTimer.Add_Tick( {
		$sqlFullPath = $tabContainer.SelectedItem.ToolTip
		$sqlFullPathArray = $sqlFullPath.Replace($SqlRootDir,"").Split("\")
		
		$Content = $window.findName("TabChildContainer").SelectedItem.Content
		$serverCombo = $Content.findName("serverComboBox")
		$sqlCombo1 = $Content.findName("sqlComboBox1")
		$sqlCombo2 = $Content.findName("sqlComboBox2")
		
		#$Server = $sqlFullPathArray[1]
		if(($serverCombo.Items.Count -gt 0) -and ($serverCombo.SelectedIndex = -1)) {
			for ($i=0; $i -lt $serverCombo.Items.Count; $i++) {
				if($serverCombo.Items[$i].ToString() -eq $sqlFullPathArray[1]) {
					$serverCombo.SelectedIndex = $i
				}
			}
			#serverComboの選択に失敗したら中止
			if($serverCombo.SelectedIndex -eq -1) {
				$this.Stop()
				return
			}
		}
		
		#$Sql1 = $sqlFullPathArray[2]
		if($sqlCombo1.Items.Count -gt 0) {
			for ($i=0; $i -lt $sqlCombo1.Items.Count; $i++) {
				if($sqlCombo1.Items[$i].ToString() -eq "├" + $sqlFullPathArray[2]) {
					$sqlCombo1.SelectedIndex = $i
				}
				if($sqlCombo1.Items[$i].ToString() -eq $sqlFullPathArray[2]) {
					$sqlCombo1.SelectedIndex = $i
					$this.Stop()
					return
				}
			}
			#sqlCombo1の選択に失敗したら中止
			if($sqlCombo1.SelectedIndex -eq -1) {
				$this.Stop()
				return
			}
		}
		
#		$Sql2 = $sqlFullPathArray[3]
		if($sqlFullPathArray.Count -gt 2) {
			if($sqlCombo2.Items.Count -gt 0) {
				for ($i=0; $i -lt $sqlCombo2.Items.Count; $i++) {
					if($sqlCombo2.Items[$i].ToString() -eq $sqlFullPathArray[3]) {
						$sqlCombo2.SelectedIndex = $i
						$this.Stop()
						return
					}
				}
				#sqlCombo2の選択に失敗したら中止
				if($sqlCombo2.SelectedIndex -eq -1) {
					$this.Stop()
					return
				}
			}
		}

	} )
	$dispatcherTimer.Start()
}

$window.add_Loaded({
	addNewTab

	$this.Icon = text2Icon($CONF.IconText)
	$this.findName("TaskbarItemInfo").Overlay = $this.Icon

	$tabContainer.Items.RemoveAt(0)

	if($null -ne $Arg1) {
		trySelectCombo $Arg1
	}
})


function text2Plain {
	Param($str)
	
	#もうちょっと良い書き方があったはず
	$TextReader = (New-Object System.Xml.XmlNodeReader ([xml]("<body>" + $str + "</body>")))

	$text_array = New-Object System.Collections.ArrayList

	while ($TextReader.Read()) {
		switch ($TextReader.NodeType) {
			"Text" {
				[void]$text_array.Add($TextReader.Value)
			}
		}
	}
	return ,($text_array -join "")
}
function text2Img {
	Param($str)

	#もうちょっと良い書き方があったはず
	$TextReader = (New-Object System.Xml.XmlNodeReader ([xml]("<body>" + $str + "</body>")))
	
	$OutBox = (New-Object System.Windows.Controls.TextBlock)
	$OutBox.Text = ""

	$text_array = New-Object System.Collections.ArrayList

	$style = ""
	$text = ""
	while ($TextReader.Read()) {
		switch ($TextReader.NodeType) {
			"Element" {
#				Write-Host ("<{0}>" -f $TextReader.Name)
				if($TextReader.AttributeCount -gt 0) {
#					Write-Host $TextReader.GetAttribute("style")
					$style =  $TextReader.GetAttribute("style")
				} else {
					$style = ""
				}
				$text = ""
			}
			"Text" {
#				Write-Host ($TextReader.Value + "a")
				$text = $TextReader.Value
				[void]$text_array.Add($TextReader.Value)
			}
			"CDATA" {
#				Write-Host $TextReader.Value
			}
			"ProcessingInstruction" {
#				Write-Host ("<?{0} {1}?>", $TextReader.Name, $TextReader.Value);
			}
			"Comment" {}
			"XmlDeclaration" {}
			"Document" {}
			"EndElement" {
#				Write-Host ("</{0}>" -f $TextReader.Name)
				$style = ""
				$text = ""
			}
			
			Default {
				$style = ""
				$text = ""
			}
		}
		if($text -ne "") {
			if($style -ne "") {
				$tmp_text = (New-Object System.Windows.Documents.Run($text))

				$style.Split(";") -ne "" | ForEach-Object {

					$s = $_.Split(":",2)
					$key = $s[0].Trim()
					$val = $s[1].Trim()

					switch ($key) {
						"color" {
							switch($val) {
								"blue" {
									$tmp_text.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Blue)
								}
								"orange" {
									$tmp_text.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Orange)
								}
								"red" {
									$tmp_text.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Red)
								}
								"lime" {
									$tmp_text.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Lime)
								}
								"gray" {
									$tmp_text.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Gray)
								}
								default {
									$tmp_text.Foreground = $val
								}
							}
						}
						"font-weight" {
							switch($val) {
								"bold" {
									$tmp_text.FontWeight = [System.Windows.FontWeights]::Bold
								}
								default {
									$tmp_text.FontWeight = $val
								}
							}
						}
						default{}
					}
				}
				$OutBox.Inlines.Add($tmp_text)
			} else {
				$tmp_text = (New-Object System.Windows.Documents.Run($text))
				$OutBox.Inlines.Add($tmp_text)
			}
		}
	}

	$fText = (New-Object System.Windows.Media.FormattedText(
		($text_array -join ""),
		[System.Globalization.CultureInfo]::CurrentCulture,
		[System.Windows.FlowDirection]::LeftToRight,
#		(New-Object System.Windows.Media.Typeface($this.FontFamily)),#デフォルトのフォント
		(New-Object System.Windows.Media.Typeface($CONF.Typeface)),
		$this.FontSize,
		$this.Foreground
		))
	$fText.MaxTextWidth = $CONF.DataGridMaxColumnWidth

	$startIndex = 0

	$OutBox.Inlines | ForEach-Object {
		$count = $_.Text.Length

		if($null -ne $_.Foreground) {
			$fText.SetForegroundBrush((New-Object System.Windows.Media.SolidColorBrush($_.Foreground.ToString())) , $startIndex, $count)
		}
		#backgroundは設定できないので文字色を変える
		<#
		if($null -ne $_.Background) {
			$fText.SetForegroundBrush((New-Object System.Windows.Media.SolidColorBrush($_.Background.ToString())) , $startIndex, $count)
		}
		#>
		
		if($null -ne $_.FontWeight) {
			$fText.SetFontWeight($_.FontWeight.ToString() , $startIndex, $count)
		}
		$startIndex = $startIndex + $count
	}

	$dv = New-Object System.Windows.Media.DrawingVisual
	$drawContext = $dv.RenderOpen()
	$drawContext.DrawText($fText, (New-Object System.Windows.Point(0, 0)))
	$drawContext.Close();

	$bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(($fText.Width), ($fText.Height), 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32);
	$bmp.Render($dv);

	return ,[System.Windows.Media.Imaging.BitmapSource]$bmp
}

function text2Icon($plain_text){
	
	$fText = (New-Object System.Windows.Media.FormattedText(
		$plain_text,
		[System.Globalization.CultureInfo]::CurrentCulture,
		[System.Windows.FlowDirection]::LeftToRight,
#			(New-Object System.Windows.Media.Typeface($this.FontFamily)),#デフォルトのフォント
		(New-Object System.Windows.Media.Typeface($CONF.Typeface)),
		$this.FontSize,
		#[System.Double]32,
		(New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::SkyBlue))
		#$this.Foreground
		))

	$dv = New-Object System.Windows.Media.DrawingVisual
	$drawContext = $dv.RenderOpen()
	$drawContext.DrawText($fText, (New-Object System.Windows.Point(0, 0)))
	$drawContext.Close();

	$bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(($fText.Width), ($fText.Height), 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32);
	$bmp.Render($dv);

	return [System.Windows.Media.Imaging.BitmapSource]$bmp
}
	
function ParseLink {
	Param($str)

	$LinkData = @{
		link = ""
		link_text = ""
		imgPath = ""
		alt = ""
		tooltip = ""
	}

	#リンク付き画像（Markdown記法）の場合
	# [![alt属性](画像ファイルのパス)](URL)
	if($str -match "\[\!\[(?<alt>[^]]+)\]\((?<img>[^)]+)\)\]\((?<url>[^)+]+)\)") {
		
		$LinkData.alt = $Matches.alt
		$img = $Matches.img
		$url = $Matches.url

		if($img -match "^`.\\") {
			$LinkData.imgPath = $PSScriptRoot + $img
		} elseif($img -match "^`./") {
			$LinkData.imgPath = $PSScriptRoot + $img
		} else {
			$LinkData.imgPath = $img
		}

		# 画像ファイルが存在しなければalt属性を表示する
		if(-not (Test-Path $linkData.imgPath)) {
			$LinkData.imgPath = ""
			$LinkData.link_text = $LinkData.alt
		}
		
		if($url -match "(?<link>[^ ]+) `"(?<tooltip>[^`"]+)`"") {
			if($Matches.link -match "^.`/") {
				$LinkData.link = $PSScriptRoot + $Matches.link
			} else {
				$LinkData.link = $Matches.link
			}

			$LinkData.tooltip = $Matches.tooltip
		} else {
			$LinkData.link = $url
		}
	# リンク（Markdown記法）の場合
	# [タイトル](URL)
	} elseif($str -match "\[(?<link_text>[^]]+)\]\((?<url>[^)+]+)\)") {
		$LinkData.link_text = $Matches.link_text
		$url = $Matches.url
		if($url -match "(?<link>[^ ]+) `"(?<tooltip>[^`"]+)`"") {
			$LinkData.link = $Matches.link
			$LinkData.tooltip = $Matches.tooltip
		} else {
			$LinkData.link = $url
		}
	} else {
		$LinkData.link = $str
	}

	if($LinkData.link_text -eq "") {
		$LinkData.link_text = $LinkData.link
	}
	$LinkData.tooltip = $LinkData.link
	if($LinkData.imgPath -ne "") {
		$LinkData.link_text = ""
		$LinkData.tooltip = $LinkData.alt
	}

	return $LinkData
}
function initDataGrid {
	Param($Content, $DT)
	Write-Debug "initDataGrid"
	<#
	カラム名が「$($CONF.TextDecorationPrefix)」で始まる場合
	「$($CONF.TextDecorationPrefix)」をカットしてHeader名とする
	クリップボードバインド用にタグを除去した文字列を、カラム名の後ろに「$($CONF.TextDecorationSuffix)」を付加したカラムに保持する
	#>

	$DataGrid = $Content.findName("DataGrid")
	
	$DataGrid.Columns.Clear()
	$DataGrid.Clear()

	$DataGrid.SelectionUnit = 2
	$DataGrid.HeadersVisibility = "All"

	$ItemSource = New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]'

	$DT.Columns | ForEach-Object {
		if($_ -match "$($CONF.TextDecorationPrefix)") {

			[xml]$ColXAML = @"
<DataGridTemplateColumn
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Header="$(($_.ToString()).Replace("$($CONF.TextDecorationPrefix)",""))" ClipboardContentBinding="{Binding $($_.ToString() + "$($CONF.TextDecorationSuffix)")}" SortMemberPath="$($_.ToString() + "$($CONF.TextDecorationSuffix)")" >

	<DataGridTemplateColumn.CellTemplate>
		<DataTemplate>
			<Image Source="{Binding $($_)}" Stretch="None" HorizontalAlignment="Left" />
		</DataTemplate>
	</DataGridTemplateColumn.CellTemplate>

	<DataGridTemplateColumn.HeaderStyle>
		<Style TargetType="DataGridColumnHeader">
			<Setter Property="ToolTip" Value="セルをダブルクリックでクリップボードにコピー" />
		</Style>
	</DataGridTemplateColumn.HeaderStyle>

	<DataGridTemplateColumn.CellStyle>
		<Style TargetType="DataGridCell">
			<Setter Property="ToolTip" Value="{Binding $($_.ToString() + "$($CONF.TextDecorationSuffix)")}" />
		</Style>
	</DataGridTemplateColumn.CellStyle>

</DataGridTemplateColumn>
"@
			$col= [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $ColXAML))
			$DataGrid.Columns.Add($col)
		} elseif($_ -match "$($CONF.StartProcessPrefix)") {
			[xml]$ColXAML = @"
<DataGridTemplateColumn
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Header="$(($_.ToString()).Replace("$($CONF.StartProcessPrefix)",""))" ClipboardContentBinding="{Binding $($_.ToString())}" SortMemberPath="$($_.ToString() + "_linkText")" >

	<DataGridTemplateColumn.CellTemplate>
		<DataTemplate>
			<Grid>
			<Image Source="{Binding $($_.ToString() + "_imgPath")}" Stretch="None" HorizontalAlignment="Left" />
			<TextBlock Text="{Binding $($_.ToString() + "_linkText")}" />
			</Grid>
		</DataTemplate>
	</DataGridTemplateColumn.CellTemplate>

	<DataGridTemplateColumn.HeaderStyle>
		<Style TargetType="DataGridColumnHeader">
			<Setter Property="ToolTip" Value="セルをダブルクリックで開く" />
		</Style>
	</DataGridTemplateColumn.HeaderStyle>

	<DataGridTemplateColumn.CellStyle>
		<Style TargetType="DataGridCell">
			<Setter Property="ToolTip" Value="{Binding $($_.ToString() + "_tooltip")}" />
		</Style>
	</DataGridTemplateColumn.CellStyle>

</DataGridTemplateColumn>
"@
			$col= [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $ColXAML))
			$DataGrid.Columns.Add($col)
		} else {
			[xml]$ColXAML = @"
<DataGridTextColumn
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Header="$($_)" Binding="{Binding $($_)}" >

	<DataGridTextColumn.HeaderStyle>
		<Style TargetType="DataGridColumnHeader">
			<Setter Property="ToolTip" Value="セルをダブルクリックでクリップボードにコピー" />
		</Style>
	</DataGridTextColumn.HeaderStyle>

	<DataGridTextColumn.CellStyle>
		<Style TargetType="DataGridCell">
			<Setter Property="ToolTip" Value="{Binding $($_)}" />
		</Style>
	</DataGridTextColumn.CellStyle>

</DataGridTextColumn>
"@
			$col= [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $ColXAML))
			$DataGrid.Columns.Add($col)
		}
	}

	$DT.Rows | ForEach-Object {
		$row = $_
		$new_row = [PSCustomObject]@{}
		$DT.Columns | ForEach-Object {
			if($_ -match "$($CONF.TextDecorationPrefix)") {
				$new_row | Add-Member -MemberType NoteProperty -Name ($_.ToString() + "$($CONF.TextDecorationSuffix)") -Value (text2Plain $row[$_])
				$new_row | Add-Member -MemberType NoteProperty -Name $_ -Value (text2Img $row[$_])
			} elseif($_ -match "$($CONF.StartProcessPrefix)") {
				$link_data = ParseLink($row[$_])
				$new_row | Add-Member -MemberType NoteProperty -Name $_ -Value $link_data.link
				$new_row | Add-Member -MemberType NoteProperty -Name ($_.ToString() + "_linkText") -Value $link_data.link_text
				$new_row | Add-Member -MemberType NoteProperty -Name ($_.ToString() + "_imgPath") -Value $link_data.imgPath
				$new_row | Add-Member -MemberType NoteProperty -Name ($_.ToString() + "_alt") -Value $link_data.alt
				$new_row | Add-Member -MemberType NoteProperty -Name ($_.ToString() + "_tooltip") -Value $link_data.tooltip
			} else {
				$new_row | Add-Member -MemberType NoteProperty -Name $_ -Value $row[$_]
			}
		}
		$ItemSource.Add($new_row)
	}

	$DataGrid.ItemsSource = $ItemSource

	$DataGrid.ScrollIntoView($null,$DataGrid.Columns[0])
	
	#テキストの折り返し設定
	$DataGrid.Columns | ForEach-Object {
		if($_.GetType().ToString() -eq "System.Windows.Controls.DataGridTextColumn") {
			$style = New-Object System.Windows.Style([System.Windows.Controls.TextBlock])
			$style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::TextWrappingProperty, [System.Windows.TextWrapping]::Wrap)))
			$_.ElementStyle = $style
		}
	}
	
}

<# Window の表示 #>
[void]$window.ShowDialog()
$window.Close()
