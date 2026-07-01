@echo off
setlocal EnableDelayedExpansion

set failed=0
set total=0
set "failedTests="

echo ========================================
echo  Running Base-Defense Test Suites (lua55)
echo ========================================

for %%F in (Testing\test_*.lua) do (
    set /a total+=1
    echo | set /p="Running %%~nxF... "
    
    lua55 "%%F" > temp_out.txt 2>&1
    if errorlevel 1 (
        set /a failed+=1
        set "failedTests=!failedTests!  - %%~nxF"
        echo [FAILED]
        echo ----------------------------------------
        type temp_out.txt
        echo ----------------------------------------
    ) else (
        echo [PASS]
    )
)

if exist temp_out.txt del temp_out.txt

echo.
echo Test Run Summary:
echo Total Suites: %total%
set /a passed=total-failed
echo Passed:       %passed%

if %failed% GTR 0 (
    echo Failed:       %failed%
    echo.
    echo Failing Suites:
    echo %failedTests%
    exit /b 1
) else (
    echo Failed:       0
    echo.
    echo All test suites passed successfully!
    exit /b 0
)
