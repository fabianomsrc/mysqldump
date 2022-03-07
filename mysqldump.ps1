#Requires -Version 5.1

<#
.SYNOPSIS
    MySQL Database Backup Script
.DESCRIPTION
    Faz o backup automático da(s) Base(s) de Dados do sistema e salva nos diretórios especificados.
.EXAMPLE
    PS C:\> powershell -ExecutionPolicy Bypass -NoProfile -NonInteractive -NoLogo -WindowStyle Hidden -File C:\Backups\BIN\mysqldump.ps1
.NOTES
    Copyright (c) Fabiano M. Silva
#>

# Nome da empresa. Evitar nomes com acentuação
$nomeEmpresa = 'Serra Dourada'

# Substitui espaços em branco por underscores
$nomeEmpresa = $nomeEmpresa.Replace(' ', '_')

# Pega a data e a hora no formato ddMMaaaa_HHmm
$currentDateTime = Get-Date -Format 'ddMMyyyy_HHmm'

# Pega o mês e ano no formato aaaaMM
$currentYearMonth = Get-Date -Format 'yyyyMM'

# Quantos dias os arquivos .sql devem ser mantidos no computador
$keepFilesForXDays = 7

<#
.SYNOPSIS
    Diretórios do Sistema
.DESCRIPTION
    Configura os diretórios que serão utilizados pelo script de backup. A estrutura
    padrão do nome do arquivo de backup é Bkp_Nome_da_Empresa_00000000_00.sql
.NOTES
    mysqlBaseDirectory: Diretório de instalação do MySQL
    sqlBackupDirectory: Diretório onde os arquivos brutos .sql serão armazenados
    zipBackupDirectory: Diretório onde os arquivos compactados serão armazenados
    mysqldumpLogError : Caminho completo do arquivo de log de erros do mysqldump

    PS: Não precisa informar a última barra no caminho dos diretórios
#>
$mysqlBaseDirectory = 'C:\wamp\bin\mysql\mysql5.7.37'
$sqlBackupDirectory = 'C:\Backups'
$zipBackupDirectory = "C:\Backups\GDrive\Bkp_MySQL_$($nomeEmpresa)\$($currentYearMonth)"
$mysqldumpLogError  = 'C:\Backups\mysqldump.log'

<#
.SYNOPSIS
    Credenciais do Banco de Dados
.DESCRIPTION
    Armazena as credenciais que serão utilizadas para se conectar ao servidor e efetuar
    o(s) backup da(s) base(s) de dados do sistema.
.NOTES
    OBS: a senha do banco de dados deve ser informada no arquivo de configuração my.ini
    no parâmetro [mysqldump] conforme exemplo a seguir:

    [mysqldump]
    quick
    password = OuYQLo!2NQ!f@KA@IUVoRtZa
#>
$mysqlDbHost = 'localhost'
$mysqlDbPort = 3306
$mysqlDbUser = 'root'
$mysqlDbName = 'm_condominio'

# Cria os direórios de backup caso os mesmos ainda não existam
try {
    if (! [string]::IsNullOrEmpty($sqlBackupDirectory)) {
        if (! (Test-Path -Path $sqlBackupDirectory)) {
            New-Item -Path $sqlBackupDirectory -ItemType Directory -ErrorAction Stop
        }
    }
    else {
        Write-Warning -Message 'O diretório de backup não foi definido.' -ErrorAction Stop
    }
    
    if (! [string]::IsNullOrEmpty($zipBackupDirectory)) {
        if (! (Test-Path -Path $zipBackupDirectory)) {
            New-Item -Path $zipBackupDirectory -ItemType Directory -ErrorAction Stop
        }
    }
    else {
        Write-Warning -Message 'O diretório de backup compactado não foi definido.' -ErrorAction Stop
    }
}
catch [System.IO.IOException] {
    Write-Warning -Message $_.Exception.Message
}

# Obtem o nome do arquivo de backup sql incluindo o caminho completo dele
function Get-BackupFileName {
    # Remove a última barra do caminho do backup caso ela exista
    if (! ($sqlBackupDirectory -match '\\$')) {
        return $("$($sqlBackupDirectory)\Bkp_$($nomeEmpresa)_$($currentDateTime).sql")
    }

    return $("$($sqlBackupDirectory.TrimEnd('\'))\Bkp_$($nomeEmpresa)_$($currentDateTime).sql")
}

# Obtem o nome do arquivo de backup compactado incluindo o caminho completo dele
function Get-CompressedBackupFileName {
    return $("$zipBackupDirectory\Bkp_$($nomeEmpresa)_$($currentDateTime).zip")
}

# Efetua a compressão do arquivo de backup sql e lança uma exception caso ele não exista
function Compress-BackupFile {
    try {
        return Compress-Archive -Path $(Get-BackupFileName) -DestinationPath $(Get-CompressedBackupFileName) -CompressionLevel Optimal -Update
    } 
    catch {
        Write-Output "O arquivo de origem $(Get-BackupFileName) não pôde ser encontrado."
    }
}

# Remove arquivos de backup sql com mais de 7 dias criados.
function Remove-OldBackupFile {
    return Get-ChildItem -Path $sqlBackupDirectory -Filter *.sql -Recurse -File |
    Where-Object { ($_.LastWriteTime -lt (Get-Date).AddDays(-$keepFilesForXDays)) } |
    Remove-Item -Force -Verbose
}

# Executa a rotina de backup propriamente dita
try {
    if (! [string]::IsNullOrEmpty($mysqlBaseDirectory)) {
        if ($mysqlBaseDirectory -match '\\$') {
            $mysqldumpDirectory = Join-Path -Path $mysqlBaseDirectory.TrimEnd('\') -ChildPath 'bin'
        }
        else {
            $mysqldumpDirectory = Join-Path -Path $mysqlBaseDirectory -ChildPath 'bin'
        }

        if (Test-Path -Path $mysqldumpDirectory) {
            # Navega para o diretório do mysqldump
            Set-Location -Path $mysqldumpDirectory

            # Executa o comando de backup
            .\mysqldump.exe -h $mysqlDbHost -u $mysqlDbUser --port=$mysqlDbPort --log-error=$mysqldumpLogError --result-file=$(Get-BackupFileName) --databases $mysqlDbName --verbose
            
            # Navega para o diretório de backup
            Set-Location -Path $sqlBackupDirectory

            # Chama a função que compacta os arquivos.
            Compress-BackupFile

            # Chama a função que remove os arquivos sql antigos.
            Remove-OldBackupFile
        }
        else {
            Write-Warning -Message "O caminho '$mysqldumpDirectory' não existe. Verifique o caminho e tente novamente." -ErrorAction Stop
        }
    }
    
    # Navega de volta para o diretório onde o script está
    Set-Location -Path $PSScriptRoot
}
catch {
    Write-Warning -Message $($_) -ErrorAction Stop
}
