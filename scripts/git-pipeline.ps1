
param (
    [string] $BranchName,
    [string] $CommitMessage = "Committed from Powershell",
    [string] $m, # Shothand for CommitMessage
    [switch] $Sync,
    [switch] $Merge,
    [switch] $Force,
    [switch] $CleanLocal
)

# Variables
$ORIGIN_URL = "https://github.com/sarbaaz0303/learn.git"
$MAIN_BRANCH = "main"

if (-not $BranchName) {
    $BranchName = $MAIN_BRANCH
}

if ($m) {
    $CommitMessage = $m
}

#Verify if Git is installed
try {
    git --version | Out-Null
}
catch {
    Write-Host "`nGit is not installed. Please install Git and try again." -ForegroundColor Red
    Exit
}

# Verify if Git is initialized
if (-not (Test-Path -Path '.\.git')) {
    git init | Out-Null
    Write-Host "`nInitialized empty Git repository."
}

# Check if the remote origin exists
if (git ls-remote $ORIGIN_URL 2>&1 | Select-String -Pattern "Repository not found") {
    Write-Host "`nThe remote origin does not exist: $ORIGIN_URL" -ForegroundColor Yellow
    Exit 
}

# Check if the remote origin is added as origin
if (!(git remote --verbose 2>&1 | Select-String -Pattern "^origin\s+$ORIGIN_URL")) {
    Write-Host "`nRemote origin does not exist. Adding it now..." -ForegroundColor Yellow
    git remote add origin $ORIGIN_URL
}

$LocalBranch = git branch --list | ForEach-Object { ($PSItem -replace '\*', '').Trim() }

$RemoteBranch = git branch --remotes | ForEach-Object { ($PSItem -replace '\*', '').Trim() }

if ($Sync) {
    # Committing current changes before syncing
    if (git status --porcelain 2>&1) {
        git add .
        git commit -m $CommitMessage
    }
    
    git fetch origin
    foreach ($Remote in $RemoteBranch) {
        $Branch = $Remote -replace 'origin/', ''
        if (git rev-parse --verify $Branch 2>&1 | Select-String -Pattern 'fatal') {
            git checkout -b $Branch $Remote
        }
        else {
            git checkout $Branch
        }
        # Merge the changes from the remote branch
        if ($Force) {
            git merge $Remote --allow-unrelated-histories
        }
        else {
            git merge $Remote
        }
    }
    Write-Host "`nChanges have been synced from remote branches." -ForegroundColor Green
    Exit
}
elseif ($Merge) {
    if (git status --porcelain 2>&1) {
        git add .
        git commit -m $CommitMessage
    }
    $CurrentBranch = git rev-parse --abbrev-ref HEAD
    Write-Host "`nCurrent branch: $CurrentBranch" -ForegroundColor Yellow

    if (($CurrentBranch -eq $MAIN_BRANCH) -and ($BranchName -eq $MAIN_BRANCH)) {
        $BranchName = (Read-Host "`nPlease provide branch name from below list.`nBranch: $($LocalBranch -join ', ')").Trim().ToLower()

        if (($BranchName -eq $MAIN_BRANCH) -or ($BranchName -eq '') -or ($LocalBranch -notcontains $BranchName)) {
            Write-Host "`nCannot merge branch: $BranchName to branch: $MAIN_BRANCH" -ForegroundColor Yellow
            Exit
        }
    }
    elseif ($BranchName -eq $MAIN_BRANCH) {
        $BranchName = $CurrentBranch
    }
    else {
        if ($LocalBranch -notcontains $BranchName) {
            Write-Host "`nCannot merge branch: $BranchName to branch: $MAIN_BRANCH" -ForegroundColor Yellow
            Exit
        }
    }

    # Confirm before merging
    $Default = 'y'
    if (!($ConfirmMerge = (Read-Host "`nAre you sure you want to merge branch: $BranchName to branch: $MAIN_BRANCH ?`n[y/n] default [$Default]").Trim().ToLower())) { $ConfirmMerge = $Default }

    if ($ConfirmMerge -ne 'y') {
        Write-Host "`nMerge aborted." -ForegroundColor Yellow
        Exit
    }
    
    git fetch origin
    $IsUpdateRequired = (git status | Select-String -Pattern '"git pull"')
    if ($IsUpdateRequired) {
        git add .
        git commit -m $CommitMessage
        git pull 2>&1 | Write-Host
        Write-Host "`nChanges have been pulled from brach: $($BranchName).`nPlease validate the changes and merge again." -ForegroundColor Yellow
        Exit
    }    

    git push -u origin $BranchName 2>&1 | Write-Host
    git checkout $MAIN_BRANCH
    git merge $BranchName

    # Confirm before merging
    $Default = 'y'
    if (!($ConfirmMerge = (Read-Host "`nAre you sure you want to delete branch: $BranchName?`n[y/n] default [$Default]").Trim().ToLower())) { $ConfirmMerge = $Default }

    if ($ConfirmMerge -ne 'y') {
        Write-Host "`nDelete aborted." -ForegroundColor Yellow
        Exit
    }

    git branch -d $BranchName
    git push origin --delete $BranchName

    Write-Host "`nMerged branch: $BranchName to branch: $MAIN_BRANCH" -ForegroundColor Green
    Exit
}
elseif ($CleanLocal) {
    $FilterBranch = $LocalBranch | Where-Object { $PSItem -ne $MAIN_BRANCH }
    if (-not $Force) {
        $FilterRemoteBranch = $RemoteBranch | ForEach-Object { $PSItem -replace 'origin/' }
        $FilterBranch = $FilterBranch | Where-Object { $PSItem -notin $FilterRemoteBranch }
    }
    Write-Host "`nBranches to be deleted: $($FilterBranch -join ', ')" -ForegroundColor Yellow

    # Confirm before merging
    $Default = 'y'
    if (!($ConfirmMerge = (Read-Host "`nAre you sure you want to delete above branches?`n[y/n] default [$Default]").Trim().ToLower())) { $ConfirmMerge = $Default }
    
    if ($ConfirmMerge -ne 'y') {
        Write-Host "`nCleanup aborted." -ForegroundColor Yellow
        Exit
    }
    if ((git rev-parse --abbrev-ref HEAD 2>&1) -ne $MAIN_BRANCH) {
        git checkout --force $MAIN_BRANCH
    }
    $FilterBranch | ForEach-Object { git branch -D $PSItem }
    Exit
}
else {
    if ($BranchName -in $LocalBranch) {
        if ((git rev-parse --abbrev-ref HEAD 2>&1) -ne $BranchName) {
            $Checkout = git checkout $BranchName 2>&1
            Write-Host $Checkout
            if ($Checkout | Select-String -Pattern 'Aborting') {
                Write-Host "`nAborted." -ForegroundColor Yellow
                Exit
            }
        }

        git fetch origin
        $IsUpdateRequired = (git status | Select-String -Pattern '"git pull"')
        if ($IsUpdateRequired) {
            git add .
            git commit -m $CommitMessage
            git pull 2>&1 | Write-Host
            Write-Host "`nChanges have been pulled from brach: $($BranchName).`nPlease validate the changes and push again." -ForegroundColor Yellow
            Exit
        }

        git add .
        git commit -m $CommitMessage
        if ($Force) {
            git push --force origin $BranchName 2>&1 | Write-Host
            Write-Host "`nChanges were forcefully pushed to branch $($BranchName)" -ForegroundColor Yellow
        }
        else {
            git push -u origin $BranchName 2>&1 | Write-Host
            Write-Host "`nSuccessfully pushed changes from branch $($BranchName) to origin" -ForegroundColor Green
        }
    }
    else {
        git checkout -b $BranchName 2>&1 | Write-Host
        git add .
        git commit -m $CommitMessage
        git push -u origin $BranchName 2>&1 | Write-Host
        Write-Host "`nSuccessfully pushed changes from branch $($BranchName) to origin" -ForegroundColor Green
    }
}
