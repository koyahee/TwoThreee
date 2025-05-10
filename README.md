# TwoThreee
PowerShellとWPFを使用してカスタムDataGridを作成し、データを表示するGUIツールです。

## 主な機能
- **SQLファイルの読み込みと実行**  
  指定されたSQLファイルを実行し、結果をDataGridに表示します。
- テキスト装飾
- 新しいプロセスを開始
  
## 使用方法
### バッチファイルから起動
同じディレクトリのバッチファイルに以下の内容を記述し、実行します。
> powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Unrestricted .\main.ps1

### ショートカットから起動
> C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Unrestricted <<ファイルパス\main.ps1>>

へのショートカットを作成し、実行します。

# 環境
以下の環境で動作確認済み。
Windows 11 Pro 24H2

