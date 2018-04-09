param([string]$testsfile=".\tests.txt", [string]$test)

$num_failed = 0
$num_passed = 0

foreach ($line in Get-Content $testsfile) {
    $ti = $line.split(" ")
    $test_expected_result = $ti[0]
    $test_name = $ti[1]

    if ($test) {
        if ($test -ne $test_name) {continue}
    }

    $proc = Start-Process -FilePath "wesnoth.exe" -ArgumentList "-d -u$($test_name)" -PassThru -NoNewWindow

    try
    {
        $proc | Wait-Process -Timeout 20 -ErrorAction Stop
    }
    catch
    {
        Write-Host "TIMEOUT`t$($test_name)" -ForegroundColor Yellow
        $proc | Stop-Process -Force
        $num_failed = $num_failed + 1
        continue
    }
    
    if($proc.ExitCode -eq $test_expected_result){
        Write-Host "SUCCESS`t$($test_name)"
        $num_passed = $num_passed + 1
    } else {
        Write-Host "FAIL`t$($test_name)`tExpected $($test_expected_result) but got $($proc.ExitCode)" -ForegroundColor Yellow
        $num_failed = $num_failed + 1
    }
}

Write-Output "`nPASSED: $num_passed FAILED: $num_failed"