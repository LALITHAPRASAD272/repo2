$ResourceGroup = "prasad-rg"
$WorkspaceName = "logs"

$StorageAccounts = @(
    "labaccount434",
    "labaccount435"
)

Write-Host "Getting Log Analytics Workspace ID..."

$LawId = az monitor log-analytics workspace show `
    --resource-group $ResourceGroup `
    --workspace-name $WorkspaceName `
    --query id -o tsv

Write-Host "Workspace ID: $LawId"

foreach ($Storage in $StorageAccounts)
{
    Write-Host "===================================="
    Write-Host "Processing Storage Account: $Storage"
    Write-Host "===================================="

    $StorageId = az storage account show `
        --name $Storage `
        --resource-group $ResourceGroup `
        --query id -o tsv

    Write-Host "Storage ID: $StorageId"

    # Blob
    $BlobId = "$StorageId/blobServices/default"

    az monitor diagnostic-settings create `
        --name "blob-diagnostics" `
        --resource $BlobId `
        --workspace $LawId `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]'

    Write-Host "Blob Diagnostics Enabled"

    # Queue
    $QueueId = "$StorageId/queueServices/default"

    az monitor diagnostic-settings create `
        --name "queue-diagnostics" `
        --resource $QueueId `
        --workspace $LawId `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]'

    Write-Host "Queue Diagnostics Enabled"

    # Table
    $TableId = "$StorageId/tableServices/default"

    az monitor diagnostic-settings create `
        --name "table-diagnostics" `
        --resource $TableId `
        --workspace $LawId `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]'

    Write-Host "Table Diagnostics Enabled"

    # File
    $FileId = "$StorageId/fileServices/default"

    az monitor diagnostic-settings create `
        --name "file-diagnostics" `
        --resource $FileId `
        --workspace $LawId `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]'

    Write-Host "File Diagnostics Enabled"
}

Write-Host "All Diagnostics Enabled Successfully"