param(
    $machineName = 'redis-vm',
    $containerName = 'redis'
)

$ErrorActionPreference = "Stop"

function print-docker-machine-status() {
    $status = docker-machine status $machineName

    Write-Host -ForegroundColor Yellow "Docker machine $machineName is $status"

    return $status
}

# make sure ssh is on path
$Env:Path = "${Env:Path};c:\Program Files (x86)\Git\bin"

try
{
    $status = print-docker-machine-status
	
	if (-not $status)
	{
		throw [System.IO.FileNotFoundException] "docker machine called $machineName not found."
	}
	
    if($status -eq "Stopped")
    {
        Write-Host -ForegroundColor Green "Starting docker machine called $machineName"
        docker-machine start $machineName
        
        print-docker-machine-status
    }
} 
catch
{
    #create docker machine
    Write-Host -ForegroundColor Yellow "Creating docker machine called $machineName"
    docker-machine create --driver virtualbox $machineName
        
    print-docker-machine-status
}

Write-Host -ForegroundColor Yellow "Connecting shell to $machineName"
$machineConfig = docker-machine env --shell powershell $machineName

if ($machineConfig -eq $null)
{
    docker-machine restart $machineName
    Write-Host -ForegroundColor Yellow "Cert errors for $machineName, regenerating certs..."
    docker-machine regenerate-certs $machineName
    $machineConfig = docker-machine env --shell powershell $machineName
}

$machineConfig

$machineConfig | Invoke-Expression

try 
{
    #$ErrorActionPreference = "Continue"
    Write-Host -ForegroundColor Yellow "Checking status of $containerName"
    $containerInfo = docker inspect $containerName | ConvertFrom-Json | Where {$_.Name -eq "/$containerName"}

    if ($containerInfo.Count -le 0) 
    {
        Write-Error "Docker container $containerName does not exist"
    }

    if (-not $containerInfo[0].State.Running) 
    {
        Write-Host -ForegroundColor Yellow "Starting $containerName"
        docker start $containerName
    }
}
catch
{
    $error[0]
    Write-Host -ForegroundColor Yellow "Starting $containerName"
    docker run -p 6379:6379 --name $containerName -d redis
}


$machineIP = docker-machine ip $machineName
Write-Host -ForegroundColor Green "Connect to redis on $($machineIP):6379"