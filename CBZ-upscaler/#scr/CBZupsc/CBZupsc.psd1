@{
  RootModule        = 'CBZupsc.psm1'
  ModuleVersion     = '0.0.1'
  Author            = 'syamatsumi'
  Description       = 'CBZのアップスケーリングと画質の検証'
  FunctionsToExport = @(
    'Get-Mediatype',
    'Update-Paths',
    'Resolve-Scale',
    'Switch-altmodloop',
    'Get-Metrics',
    'Search-Metrics'
  )
  PowerShellVersion = '7.0'
}
