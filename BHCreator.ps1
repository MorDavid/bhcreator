# Starting string
$start_string = "BHCREATOR"

# Function to generate a random password
function Generate-Password {
    $characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    $random = -join ((1..8) | ForEach-Object { $characters[(Get-Random -Maximum $characters.Length)] })
    return "${start_string}${random}"
}

# Function to check if the log entry is present
function Check-LogEntry {
    docker compose logs | Select-String "Initial Password Set To" -Quiet
}

# Generate random password
$random_password = Generate-Password

Write-Host '  ____  _   _    ____                _             '
Write-Host ' | __ )| | | |  / ___|_ __ ___  __ _| |_ ___  _ __ '
Write-Host " |  _ \| |_| | | |   | '__/ _ \/ _\` | __/ _ \| '__|"
Write-Host ' | |_) |  _  | | |___| | |  __/ (_| | || (_) | |   '
Write-Host ' |____/|_| |_|  \____|_|  \___|\__,_|\__\___/|_|   '
Write-Host '                                                   '
Write-Host '                                    by Mor David   '
Write-Host '                                                   '

# Check if Docker is installed
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[X] Docker Desktop is not installed. Please install it first."
    exit 1
}

# Check Docker Compose
docker compose version
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Docker Compose not working. Please check Docker Desktop installation."
    exit 1
}

# List of container and volumes names to check
$VOLUMES = @("bloodhound_docker_postgres-data", "bloodhound_docker_neo4j-data")
$CONTAINERS = @("bloodhound_docker-app-db-1", "bloodhound_docker-graph-db-1", "bloodhound_docker-bloodhound-1")

foreach ($CONTAINER in $CONTAINERS) {
    $IS_RUNNING = docker ps --filter name="$CONTAINER" --format '{{.ID}}'
    if ($IS_RUNNING) {
        Write-Host "[-] $CONTAINER is running. Stopping and removing container..."
        docker container stop $CONTAINER | Out-Null
        docker container rm $CONTAINER | Out-Null
    }
}

foreach ($VOLUME in $VOLUMES) {
    $VOLUME_EXISTS = docker volume ls -q --filter name="$VOLUME"
    if ($VOLUME_EXISTS) {
        Write-Host "[-] $VOLUME exists. Removing volume..."
        docker volume rm $VOLUME | Out-Null
    }
}

$DIR = "bloodhound_docker"
if (-not (Test-Path $DIR)) {
    New-Item -ItemType Directory -Path $DIR | Out-Null
    Write-Host "[+] Directory '$DIR' created."
}
else {
    Write-Host "[+] Directory '$DIR' already exists."
}
Set-Location $DIR

Write-Host '[+] Download .env.example'
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/.env.example" -OutFile ".env"
Write-Host '[+] Download bloodhound.config.json'
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/bloodhound.config.json" -OutFile "bloodhound.config.json"
Write-Host '[+] Download docker-compose.yml'
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/docker-compose.yml" -OutFile "docker-compose.yml"

Write-Host '[+] Editing bloodhound.config.json'
(Get-Content bloodhound.config.json) -replace 'spam@example.com', 'info@mdapp.co.il' | Set-Content bloodhound.config.json -Encoding utf8
(Get-Content bloodhound.config.json) -replace '"Bloodhound"', '"Mor"' | Set-Content bloodhound.config.json -Encoding utf8
(Get-Content bloodhound.config.json) -replace '"Admin"', '""' | Set-Content bloodhound.config.json -Encoding utf8

Write-Host '[+] Editing .env'
(Get-Content .env) -replace 'BLOODHOUND_HOST=127.0.0.1', 'BLOODHOUND_HOST=0.0.0.0' | Set-Content .env -Encoding utf8
(Get-Content .env) -replace 'BLOODHOUND_PORT=8080', 'BLOODHOUND_PORT=6990' | Set-Content .env -Encoding utf8
(Get-Content .env) -replace '# Default Admin', '# Default Admin - MD Edison' | Set-Content .env -Encoding utf8
(Get-Content .env) -replace 'bloodhoundcommunityedition', $random_password | Set-Content .env -Encoding utf8
(Get-Content .env) -replace '#bhe_default_admin_principal_name=', 'bhe_default_admin_principal_name=md' | Set-Content .env -Encoding utf8
(Get-Content .env) -replace '#bhe_default_admin_password=', 'bhe_default_admin_password=Aa123456789!' | Set-Content .env -Encoding utf8
(Get-Content .env) -replace '#bhe_default_admin_email_address=', 'bhe_default_admin_email_address=info@mdapp.co.il' | Set-Content .env -Encoding utf8
(Get-Content .env) -replace '#bhe_default_admin_first_name=', 'bhe_default_admin_first_name=Mor' | Set-Content .env -Encoding utf8
(Get-Content .env) -replace '#bhe_default_admin_last_name=', 'bhe_default_admin_last_name=BH' | Set-Content .env -Encoding utf8

Write-Host '[+] Editing docker-compose.yml'
(Get-Content docker-compose.yml) -replace '127.0.0.1:\${NEO4J_DB_PORT:-7687}:7687', '0.0.0.0:${NEO4J_DB_PORT:-7687}:7687' | Set-Content docker-compose.yml -Encoding utf8
(Get-Content docker-compose.yml) -replace '127.0.0.1:\${NEO4J_WEB_PORT:-7474}:7474', '0.0.0.0:${NEO4J_WEB_PORT:-7474}:7474' | Set-Content docker-compose.yml -Encoding utf8
(Get-Content docker-compose.yml) -replace '# volumes:', 'volumes:' | Set-Content docker-compose.yml -Encoding utf8
(Get-Content docker-compose.yml) -replace '#   - .\/bloodhound.config.json:\/bloodhound.config.json:ro', '  - ./bloodhound.config.json:/bloodhound.config.json:ro' | Set-Content docker-compose.yml -Encoding utf8

Write-Host '[+] docker compose up -d'
docker compose up -d

Write-Host "`n[+] Bloodhound's credentials:"
Write-Host 'Email: info@mdapp.co.il'

Write-Host "Waiting for the log entry: 'Initial Password Set To'..."
while (-not (Check-LogEntry)) {
    Start-Sleep -Seconds 1
}

$password = docker logs bloodhound_docker-bloodhound-1 2>&1 | Select-String "Initial Password Set To" | ForEach-Object { 
    if ($_ -match '"message":"#\sInitial\sPassword\sSet\sTo:\s+([^#\s]+)\s+#"') {
        $matches[1]
    }
}
Write-Host "Password: $password"

Write-Host "`n[+] Neo4j's credentials:"
Write-Host 'Username: neo4j'
Write-Host "Password: $random_password"
Write-Host "`n[+] Done, Happy Graphing!" 