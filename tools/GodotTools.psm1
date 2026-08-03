function Resolve-NumblopGodot {
    param([string]$GodotPath = "")

    if ($GodotPath) {
        if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
            throw "Godot executable not found: $GodotPath"
        }
        return (Resolve-Path -LiteralPath $GodotPath).Path
    }

    foreach ($name in @("godot4", "godot")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $godotRoot = Join-Path (Split-Path $repoRoot -Parent) "Godot"
    $candidate = Get-ChildItem -LiteralPath $godotRoot -File -ErrorAction SilentlyContinue |
        Where-Object Name -Match '^Godot.*_console\.exe$' |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -ne $candidate) {
        return $candidate.FullName
    }

    throw "Godot was not found on PATH or in the sibling Godot directory."
}

function Invoke-NumblopGodot {
    param(
        [Parameter(Mandatory)] [string]$Godot,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [string]$ExpectedMarker = "",
        [string[]]$AllowedErrorPatterns = @(),
        [int]$TimeoutSeconds = 120
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Godot
    $startInfo.Arguments = (($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Could not start Godot."
        }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            throw "Godot timed out after $TimeoutSeconds seconds."
        }
        $output = $stdout.Result + $stderr.Result
        if ($output.Trim()) {
            Write-Host $output.TrimEnd()
        }
        if ($process.ExitCode -ne 0) {
            throw "Godot failed with exit code $($process.ExitCode)."
        }
        if ($output -match '(?m)SCRIPT ERROR:|Parse Error:') {
            throw "Godot reported a script error."
        }
        $errorLines = @($output -split "`r?`n" | Where-Object { $_ -match '^ERROR:' })
        foreach ($line in $errorLines) {
            $allowed = $false
            foreach ($pattern in $AllowedErrorPatterns) {
                if ($line -match $pattern) {
                    $allowed = $true
                    break
                }
            }
            if (-not $allowed) {
                throw "Godot reported an error: $line"
            }
        }
        if ($ExpectedMarker -and $output -notmatch [regex]::Escape($ExpectedMarker)) {
            throw "Godot did not print $ExpectedMarker."
        }
    }
    finally {
        if (-not $process.HasExited) {
            $process.Kill()
        }
        $process.Dispose()
    }
}

function Initialize-NumblopProject {
    param(
        [Parameter(Mandatory)] [string]$Godot,
        [Parameter(Mandatory)] [string]$RepoRoot
    )

    $translationOutputs = @(
        (Join-Path $RepoRoot "localization\strings.en.translation"),
        (Join-Path $RepoRoot "localization\strings.cs.translation")
    )
    $missingTranslations = @($translationOutputs | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($missingTranslations.Count -gt 0) {
        Invoke-NumblopGodot -Godot $Godot -Arguments @(
            "--headless", "--path", $RepoRoot, "--import"
        ) -AllowedErrorPatterns @(
            "Cannot open file 'res://localization/strings\.(en|cs)\.translation'",
            "Failed loading resource: res://localization/strings\.(en|cs)\.translation"
        )
        foreach ($path in $translationOutputs) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Godot did not generate translation resource: $path"
            }
        }
    }

    Invoke-NumblopGodot -Godot $Godot -Arguments @(
        "--headless", "--path", $RepoRoot, "--import"
    )
}

function Resolve-NumblopJarsigner {
    param([string]$JarsignerPath = "")

    if ($JarsignerPath) {
        if (-not (Test-Path -LiteralPath $JarsignerPath -PathType Leaf)) {
            throw "jarsigner not found: $JarsignerPath"
        }
        return (Resolve-Path -LiteralPath $JarsignerPath).Path
    }

    if ($env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME "bin\jarsigner.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    $command = Get-Command jarsigner -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    # Godot's Android export uses a JDK 17 that is often installed without JAVA_HOME or PATH.
    $jdkRoots = @(
        (Join-Path ${env:ProgramFiles} "Eclipse Adoptium"),
        (Join-Path ${env:ProgramFiles} "Java")
    )
    foreach ($jdkRoot in $jdkRoots) {
        if (-not (Test-Path -LiteralPath $jdkRoot -PathType Container)) {
            continue
        }
        $candidate = Get-ChildItem -LiteralPath $jdkRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName "bin\jarsigner.exe" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
        if ($null -ne $candidate) {
            return $candidate
        }
    }

    throw "jarsigner not found. Set JAVA_HOME to the JDK used for Android exports."
}

function Unprotect-NumblopPassword {
    param([Parameter(Mandatory)] [string]$PasswordFile)

    if (-not (Test-Path -LiteralPath $PasswordFile -PathType Leaf)) {
        throw "Password file not found: $PasswordFile"
    }
    try {
        $secure = ConvertTo-SecureString (Get-Content -LiteralPath $PasswordFile -Raw).Trim()
    }
    catch {
        throw ("Could not decrypt $PasswordFile. DPAPI ciphertext only opens for the " +
            "Windows account and machine that created it. Recreate it with " +
            "tools/save-keystore-password.ps1.")
    }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        $secure.Dispose()
    }
}

Export-ModuleMember -Function Resolve-NumblopGodot, Invoke-NumblopGodot, Initialize-NumblopProject, Resolve-NumblopJarsigner, Unprotect-NumblopPassword
