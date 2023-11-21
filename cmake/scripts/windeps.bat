@echo off
setlocal enabledelayedexpansion

:: ��ʼ������
set "INPUT_DIR="
set "PLUGIN_DIR="
set "LIB_DIR="
set "QMAKE_PATH="
set "QMCORECMD_PATH="
set "VERBOSE="
set "FILES="
set "EXTRA_PLUGIN_PATHS="
set "PLUGINS="
set "COPY_ARGS="

:: ���������в���
:parse_args
if "%~1"=="" goto :end_parse_args
if "%1"=="-i" set "INPUT_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="-p" set "PLUGIN_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="-l" set "LIB_DIR=%~2" & shift & shift & goto :parse_args
if "%1"=="-q" set "QMAKE_PATH=%~2" & shift & shift & goto :parse_args
if "%1"=="-P" set "EXTRA_PLUGIN_PATHS=!EXTRA_PLUGIN_PATHS! %~2" & shift & shift & goto :parse_args
if "%1"=="-m" set "QMCORECMD_PATH=%~2" & shift & shift & goto :parse_args
if "%1"=="-t" set "PLUGINS=!PLUGINS! %~2" & shift & shift & goto :parse_args
if "%1"=="-c" set "COPY_ARGS=!COPY_ARGS! -c %~2 %~3" & shift & shift & shift & goto :parse_args
if "%1"=="-f" set "ARGS=!ARGS! -f" & shift & goto :parse_args
if "%1"=="-s" set "ARGS=!ARGS! -s" & shift & goto :parse_args
if "%1"=="-V" set "VERBOSE=-V" & shift & goto :parse_args
if "%1"=="-h" call :usage & exit /b

if "%1"=="-@" set "ARGS=!ARGS! -@ %~2" & shift & shift & goto :parse_args
if "%1"=="-L" set "ARGS=!ARGS! -L %~2" & shift & shift & goto :parse_args

shift
goto :parse_args
:end_parse_args

:: ���������
if not defined INPUT_DIR echo Error: Missing required argument 'INPUT_DIR' & call :usage & exit /b
if not defined PLUGIN_DIR echo Error: Missing required argument 'PLUGIN_DIR' & call :usage & exit /b
if not defined LIB_DIR echo Error: Missing required argument 'LIB_DIR' & call :usage & exit /b
if not defined QMCORECMD_PATH echo Error: Missing required argument 'QMCORECMD_PATH' & call :usage & exit /b

:: ��ȡ Qt �����װ·��
if defined QMAKE_PATH (
    for /f "tokens=*" %%a in ('!QMAKE_PATH! -query QT_INSTALL_PLUGINS') do set "QMAKE_PLUGIN_PATH=%%a"
    set "PLUGIN_PATHS=!QMAKE_PLUGIN_PATH!"
)

:: ��Ӷ���Ĳ������·��
set "PLUGIN_PATHS=!PLUGIN_PATHS! !EXTRA_PLUGIN_PATHS!"

:: ���ݲ���ϵͳ�����������ļ�����
:: Windows ���������� .exe �� .dll �ļ�
for /r "%INPUT_DIR%" %%f in (*.exe *.dll) do (
    set "FILES=!FILES! %%f"
)

:: ���� Qt ���������·��
for %%p in (!PLUGINS!) do (
    set "plugin_path=%%p"

    :: ����ʽ
    echo !plugin_path! | findstr /R "[^/]*\/[^/]*" >nul
    if errorlevel 1 (
        echo Error: Invalid plugin format '!plugin_path!'. Expected format: ^<category^>/^<name^>
        exit /b
    )

    :: ��ȡ��������
    for /f "tokens=1,2 delims=/" %%a in ("!plugin_path!") do (
        set "category=%%a"
        set "name=%%b"

        :: ����·�������Ҿ������ļ�
        set "FOUND_PLUGIN="
        call :search_plugin

        if not defined FOUND_PLUGIN (
            echo Error: Plugin '!plugin_path!' not found in any search paths.
            exit /b
        )

        set "DESTINATION_DIR=!PLUGIN_DIR!\!category!"
        set "DESTINATION_DIR=!DESTINATION_DIR:/=\!"

        mkdir "!DESTINATION_DIR!" >nul 2>&1
        set "FILES=!FILES! -c !FOUND_PLUGIN! !DESTINATION_DIR!"
    )
)

:: ��Ӷ���� -c ����
set "FILES=!FILES! !COPY_ARGS!"

:: ������ִ�� qmcorecmd deploy ����
set "DEPLOY_CMD=!QMCORECMD_PATH! deploy !FILES! !ARGS! !VERBOSE! -o !LIB_DIR!"
if "!VERBOSE!"=="-V" echo Executing: !DEPLOY_CMD!
call !DEPLOY_CMD!

:: ��鲿����
if %errorlevel% neq 0 exit /b
exit /b

:: ���Ҳ��
:search_plugin
for %%d in (!PLUGIN_PATHS!) do (
    for %%f in ("%%d\!category!\!name!*") do (
        if exist "%%f" (
            set "FOUND_PLUGIN=%%f"
            exit /b
        )
    )
)
exit /b

:: ��ʾ���
:usage
echo Usage: %~nx0 -i ^<input_dir^> -p ^<plugin_dir^> -l ^<lib_dir^> -m ^<qmcorecmd_path^>
echo                     [-q ^<qmake_path^>] [-P ^<extra_path^>]...
echo                     [-t ^<plugin^>]... [-c ^<src^> ^<dest^>]... [-f] [-s] [-V] [-h]
echo                     [-f] [-s] [-V] [-h]
echo                     [-@ ^<file^>]... [-L ^<path^>]...
exit /b