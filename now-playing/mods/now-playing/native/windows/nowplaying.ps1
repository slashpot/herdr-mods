# nowplaying: read and control the system media sessions on Windows through
# GSMTC (Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager).
# Needs Windows PowerShell 5.1 (powershell.exe): it reaches WinRT, PowerShell 7 does not.
#
#   get <art-dir> [known]     one line of JSON: { "elected": aumid | null, "sessions": [Track, ...] }
#                             one Track per app with a title; artwork is written to <art-dir>.
#                             known is a |-separated list of AUMIDs whose app name the caller
#                             already has: their Track carries no app, which saves a lookup.
#   send <command> [aumid]    command: play | pause | toggle | next | previous
#                             to that app's session, or to the current one without an aumid.
#                             Prints 1 when the session accepted it, 0 when it refused;
#                             exits 4 when there is no such session.
#
# Output is ASCII: every non-ASCII character is a \u escape, so the console code page can't mangle it.
param([string]$Command, [string]$Arg, [string]$Extra)
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime]
$null = [Windows.ApplicationModel.AppInfo, Windows.ApplicationModel, ContentType = WindowsRuntime]

$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
function Await($op, [Type]$type) {
  $task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
  [void]$task.Wait(-1)
  $task.Result
}

function Emit($value) {
  $json = ConvertTo-Json $value -Depth 5 -Compress
  [regex]::Replace($json, '[^\x00-\x7f]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
}

$Manager = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$mgr = Await ($Manager::RequestAsync()) $Manager

# The Start menu name of an app. AppInfo knows packaged apps; the AppsFolder
# knows the rest (Chrome's AUMID is just "Chrome").
$script:apps = $null
function AppName([string]$id) {
  try { return [Windows.ApplicationModel.AppInfo]::GetFromAppUserModelId($id).DisplayInfo.DisplayName } catch {}
  try {
    if (-not $script:apps) { $script:apps = (New-Object -ComObject Shell.Application).NameSpace('shell:AppsFolder') }
    $item = $script:apps.ParseName($id)
    if ($item) { return $item.Name }
  } catch {}
  $id
}

# A file name safe for any AUMID. The hash comes after the last dash, so pruning
# can tell which session a file belongs to.
function SafeName([string]$id) { $id -replace '[\\/:*?"<>|\-\s]', '_' }

$sha1 = [Security.Cryptography.SHA1]::Create()
function SaveArt($session, $props, [string]$dir) {
  if (-not $dir -or -not $props.Thumbnail) { return $null }
  $stream = Await ($props.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
  # PowerShell sees the stream as a bare __ComObject; reflection still casts it to its interfaces.
  $asStream = [System.IO.WindowsRuntimeStreamExtensions].GetMethod('AsStreamForRead', [type[]]@([Windows.Storage.Streams.IInputStream]))
  $buffer = New-Object IO.MemoryStream
  $asStream.Invoke($null, @($stream)).CopyTo($buffer)
  if (-not $buffer.Length) { return $null }
  $type = [Windows.Storage.Streams.IContentTypeProvider].GetProperty('ContentType').GetValue($stream)
  $ext = if ($type -match 'png') { 'png' } else { 'jpg' }
  $bytes = $buffer.ToArray()
  $hash = -join ($sha1.ComputeHash($bytes)[0..7] | ForEach-Object { $_.ToString('x2') })
  $name = "$(SafeName $session.SourceAppUserModelId)-$hash.$ext"
  $path = Join-Path $dir $name
  if (-not (Test-Path -LiteralPath $path)) {
    $tmp = "$path.tmp"
    [IO.File]::WriteAllBytes($tmp, $bytes)
    Move-Item -LiteralPath $tmp -Destination $path -Force
  }
  $name
}

# Removes every picture no session shows, except those of a session whose
# artwork hasn't arrived yet: the UI keeps showing that session's last one.
function PruneArt($sessions, [string]$dir) {
  if (-not $dir) { return }
  $keep = @{}; $waiting = @{}
  foreach ($s in $sessions) {
    if ($s.art) { $keep[$s.art] = $true } else { $waiting[(SafeName $s.bundle)] = $true }
  }
  foreach ($file in Get-ChildItem -LiteralPath $dir -File) {
    $dash = $file.Name.LastIndexOf('-')
    $owner = if ($dash -gt 0) { $file.Name.Substring(0, $dash) } else { '' }
    if ($keep[$file.Name] -or $waiting[$owner]) { continue }
    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
  }
}

function Finite($x) { -not ([double]::IsNaN($x) -or [double]::IsInfinity($x)) }

function Get-Sessions([string]$dir, [string]$known) {
  $named = @{}
  foreach ($k in ($known -split '\|')) { if ($k) { $named[$k] = $true } }
  if ($dir) { $null = New-Item -ItemType Directory -Force -Path $dir }
  $current = $mgr.GetCurrentSession()
  $seen = @{}
  $sessions = @()
  foreach ($s in $mgr.GetSessions()) {
    $id = $s.SourceAppUserModelId
    if ($seen[$id]) { continue } # the mod keys sessions by app
    $props = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
    if (-not $props.Title) { continue }
    $seen[$id] = $true
    $timeline = $s.GetTimelineProperties()
    $playback = $s.GetPlaybackInfo()
    $playing = $playback.PlaybackStatus -eq [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionPlaybackStatus]::Playing
    $rate = 0
    if ($playing) { $rate = if ($playback.PlaybackRate -gt 0) { [double]$playback.PlaybackRate } else { 1 } }
    $track = [ordered]@{
      title = $props.Title
      artist = $props.Artist
      album = $props.AlbumTitle
      bundle = $id
      rate = $rate
      controllable = $true
      pickable = $true
    }
    if (-not $named[$id]) { $track.app = AppName $id }
    $duration = ($timeline.EndTime - $timeline.StartTime).TotalSeconds
    if ($duration -gt 0 -and (Finite $duration)) { $track.duration = $duration }
    $elapsed = $timeline.Position.TotalSeconds
    if (Finite $elapsed) { $track.elapsed = [math]::Max([double]0, $elapsed) }
    $stamp = $timeline.LastUpdatedTime.ToUnixTimeMilliseconds()
    if ($stamp -gt 0) { $track.timestamp = $stamp / 1000 }
    $art = SaveArt $s $props $dir
    if ($art) { $track.art = $art }
    $sessions += $track
  }
  PruneArt $sessions $dir
  [ordered]@{
    elected = if ($current) { $current.SourceAppUserModelId } else { $null }
    sessions = $sessions
  }
}

function Send-Command([string]$name, [string]$id) {
  $target = if ($id) { $mgr.GetSessions() | Where-Object { $_.SourceAppUserModelId -eq $id } | Select-Object -First 1 } else { $mgr.GetCurrentSession() }
  if (-not $target) {
    [Console]::Error.WriteLine("no media session for $(if ($id) { $id } else { 'the current app' })")
    exit 4
  }
  $op = switch ($name) {
    'play' { $target.TryPlayAsync() }
    'pause' { $target.TryPauseAsync() }
    'toggle' { $target.TryTogglePlayPauseAsync() }
    'next' { $target.TrySkipNextAsync() }
    'previous' { $target.TrySkipPreviousAsync() }
    default { [Console]::Error.WriteLine("unknown command: $name (play|pause|toggle|next|previous)"); exit 2 }
  }
  if (Await $op ([bool])) { '1' } else { '0' }
}

switch ($Command) {
  'get' { Emit (Get-Sessions $Arg $Extra) }
  'send' { Send-Command $Arg $Extra }
  default {
    [Console]::Error.WriteLine('usage: nowplaying.ps1 get <art-dir> | send <play|pause|toggle|next|previous> [aumid]')
    exit 2
  }
}
