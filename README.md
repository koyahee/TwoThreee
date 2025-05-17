# TwoThreee
PowerShellとWPFを使用してカスタムDataGridを作成し、データを表示するGUIツールです。
![image](https://github.com/user-attachments/assets/7ae89850-83ae-4e9b-b518-410f8b09cfe3)


## 主な機能
- **SQLファイルの読み込みと実行**  
  指定されたSQLファイルを実行し、結果をDataGridに表示します。
- テキスト装飾
- 新しいプロセスを開始

## 初期設定
1. sqlフォルダ内のdemoフォルダをコピーし、適当な名前を付けて保存。
2. connect.udlの内容を環境に合わせて変更する。  
  （初期状態ではlocalhost￥SQLEXPRESSに接続します。）

以上でSQLが実行可能な状態になります。

## 使用方法
### バッチファイルから起動
同じディレクトリのバッチファイルに以下の内容を記述し、実行します。  
引数にsqlフォルダ内のSQLファイルのフルパスを渡すと、起動時に開きます。
> powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Unrestricted .\main.ps1  
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Unrestricted .\main.ps1 "SQLファイルのフルパス"

### ショートカットから起動
> C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Unrestricted <<ファイルパス\main.ps1>>  
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Unrestricted <<ファイルパス\main.ps1>> "SQLファイルのフルパス"

へのショートカットを作成し、実行します。

# 環境
以下の環境で動作確認済み。
Windows 11 Pro 24H2

