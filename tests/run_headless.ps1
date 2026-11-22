param([string[]]$Tests = @(), [string]$Tag = 'p133')
# Isolated test copy: virtual mouse-capture state, real Godot actions/physics.
# Production source and OS cursor/focus are untouched. Screenshots need the single final window smoke.
$ErrorActionPreference = 'Stop'
$projectRoot = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { (Get-Location).Path }
$copyRoot = Join-Path $projectRoot ".godot/headless_$Tag"
$godot = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
$utf8 = [Text.UTF8Encoding]::new($false)
$files = @(git -C $projectRoot ls-files --cached --others --exclude-standard)
foreach ($relative in $files) {
    $source = Join-Path $projectRoot $relative
    $target = Join-Path $copyRoot $relative
    [IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    if ($relative.EndsWith('.gd')) {
        $text = [IO.File]::ReadAllText($source).Replace('Input.mouse_mode','HeadlessTestInput.mouse_mode')
        if ($relative.StartsWith('tests/')) {
            $text = $text.Replace('Input.parse_input_event(', 'HeadlessTestInput.parse_input_event(')
            $text = $text.Replace('root.grab_focus()', 'pass').Replace('if DisplayServer.get_name() == "headless":','if false: # Virtual capture supported by this isolated test copy.')
            $text = $text.Replace('await RenderingServer.frame_post_draw','await process_frame')
            $text = [regex]::Replace($text,'(?m)^(\s*)root\.get_texture\(\)\.get_image\(\)\.save_png\([^\r\n]*','$1pass # Screenshot covered by final window smoke.')
            $text = [regex]::Replace($text,'(?m)^(\t*)quit\(','$1print("HEADLESS TEST completed")' + "`n" + '$1quit(')
        }
        [IO.File]::WriteAllText($target,$text,$utf8)
    } else { Copy-Item -LiteralPath $source -Destination $target -Force }
}
[IO.File]::WriteAllText((Join-Path $copyRoot 'scripts/headless_test_input.gd'),@'
class_name HeadlessTestInput
extends RefCounted
static var mouse_mode: int = Input.MOUSE_MODE_VISIBLE
static func parse_input_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Synthetic look deltas are already viewport pixels, not dummy OS window coordinates.
		Engine.get_main_loop().root.push_input(event,true)
	else:
		Input.parse_input_event(event)
'@,$utf8)
$importLog = Join-Path $projectRoot ".godot/${Tag}_headless_import.log"
$p = Start-Process $godot -ArgumentList @('--headless','--path',$copyRoot,'--editor','--import','--quit','--log-file',$importLog) -WindowStyle Hidden -PassThru -Wait
if ($p.ExitCode -ne 0 -or (Select-String -Path $importLog -Pattern 'SCRIPT ERROR|^ERROR:')) { throw 'Headless copy import failed' }
if ($Tests.Count -eq 0) {
    $Tests = @(Get-ChildItem (Join-Path $projectRoot 'tests/prompt*.gd') | Where-Object { $_.BaseName -notmatch 'probe|measure|reproduce|observation' } | ForEach-Object BaseName)
    # These are established regression fixtures despite their historical names.
    $Tests += @('prompt11_8_observation','prompt12_9_reproduce','prompt11_4_reproduce','prompt12_1_measure','prompt12_4_probe')
}
$results = @()
foreach ($test in $Tests) {
    $log = Join-Path $projectRoot ".godot/${Tag}_${test}.log"
    $p = Start-Process $godot -ArgumentList @('--headless','--path',$copyRoot,'--fixed-fps','60','--script',"res://tests/$test.gd",'--quit-after','24000','--log-file',$log) -WindowStyle Hidden -PassThru -Wait
    $lines = Get-Content $log
    $results += [pscustomobject]@{script=$test;exit=$p.ExitCode;pass=@($lines | Select-String '^PASS:').Count;errors=@($lines | Select-String 'SCRIPT ERROR|^ERROR:|^WARNING:|FAIL:').Count;completed=[bool]($lines -match 'completed|failures:');log=$log}
    $results | Export-Csv (Join-Path $projectRoot ".godot/${Tag}_results.csv") -NoTypeInformation
    $results[-1] | ConvertTo-Json -Compress
}
