param(
  [Parameter(Mandatory=$true)][string]$CsvPath,
  [Parameter(Mandatory=$false)][string]$OutputHtml = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $CsvPath)) {
  throw "CSV not found: $CsvPath"
}

if ([string]::IsNullOrWhiteSpace($OutputHtml)) {
  $OutputHtml = Join-Path (Split-Path -Parent $CsvPath) 'memory_report.html'
}

$rows = Import-Csv -Path $CsvPath
if (-not $rows -or $rows.Count -eq 0) {
  throw 'CSV has no rows.'
}

$parsed = @()
foreach ($r in $rows) {
  try {
    $dt = [datetime]$r.timestamp
  } catch {
    continue
  }

  $pss = 0
  [void][int]::TryParse($r.total_pss_kb, [ref]$pss)
  $rss = 0
  [void][int]::TryParse($r.total_rss_kb, [ref]$rss)
  $priv = 0
  [void][int]::TryParse($r.private_dirty_kb, [ref]$priv)
  $heapAlloc = 0
  [void][int]::TryParse($r.native_heap_alloc_kb, [ref]$heapAlloc)
  $heapSize = 0
  [void][int]::TryParse($r.native_heap_size_kb, [ref]$heapSize)

  $parsed += [PSCustomObject]@{
    timestamp = $dt
    package = $r.package
    pid = $r.pid
    pss = $pss
    rss = $rss
    privateDirty = $priv
    heapAlloc = $heapAlloc
    heapSize = $heapSize
    memTotal = $r.mem_total_kb
    memAvailable = $r.mem_available_kb
  }
}

if ($parsed.Count -eq 0) {
  throw 'No parseable rows in CSV.'
}

$start = ($parsed | Sort-Object timestamp | Select-Object -First 1).timestamp
$end = ($parsed | Sort-Object timestamp | Select-Object -Last 1).timestamp
$durationMin = [Math]::Round((($end - $start).TotalMinutes), 2)

$packages = $parsed | Select-Object -ExpandProperty package -Unique
$series = @{}
$stats = @()

foreach ($pkg in $packages) {
  $pkgRows = $parsed | Where-Object { $_.package -eq $pkg } | Sort-Object timestamp
  $points = @()
  foreach ($row in $pkgRows) {
    $x = [Math]::Round((($row.timestamp - $start).TotalSeconds / 60.0), 3)
    $points += [PSCustomObject]@{
      x = $x
      pss = $row.pss
      rss = $row.rss
      privateDirty = $row.privateDirty
      heapAlloc = $row.heapAlloc
      heapSize = $row.heapSize
    }
  }
  $series[$pkg] = $points

  $pssValues = $pkgRows | Select-Object -ExpandProperty pss
  $rssValues = $pkgRows | Select-Object -ExpandProperty rss
  $stats += [PSCustomObject]@{
    package = $pkg
    samples = $pkgRows.Count
    pssStart = $pssValues[0]
    pssEnd = $pssValues[$pssValues.Count - 1]
    pssMin = ($pssValues | Measure-Object -Minimum).Minimum
    pssMax = ($pssValues | Measure-Object -Maximum).Maximum
    pssAvg = [Math]::Round(($pssValues | Measure-Object -Average).Average, 2)
    rssStart = $rssValues[0]
    rssEnd = $rssValues[$rssValues.Count - 1]
    rssMin = ($rssValues | Measure-Object -Minimum).Minimum
    rssMax = ($rssValues | Measure-Object -Maximum).Maximum
    rssAvg = [Math]::Round(($rssValues | Measure-Object -Average).Average, 2)
  }
}

$seriesJson = $series | ConvertTo-Json -Depth 8
$statsRows = ($stats | ForEach-Object {
  "<tr><td>$($_.package)</td><td>$($_.samples)</td><td>$($_.pssStart)</td><td>$($_.pssEnd)</td><td>$($_.pssMin)</td><td>$($_.pssMax)</td><td>$($_.pssAvg)</td><td>$($_.rssStart)</td><td>$($_.rssEnd)</td><td>$($_.rssMin)</td><td>$($_.rssMax)</td><td>$($_.rssAvg)</td></tr>"
}) -join "`n"

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Memory Tracking Report</title>
  <style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; background: #0b1020; color: #e6edf3; }
    h1, h2 { margin: 0 0 12px; }
    .muted { color: #9fb0c3; }
    .grid { display: grid; grid-template-columns: 1fr; gap: 16px; }
    .card { background: #121a2e; border: 1px solid #26324a; border-radius: 10px; padding: 14px; }
    canvas { width: 100%; height: 320px; background: #0e1628; border-radius: 8px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #2a3a59; padding: 8px; font-size: 12px; }
    th { background: #1c2842; }
    .legend { display: flex; gap: 14px; flex-wrap: wrap; margin: 8px 0 0; }
    .legend-item { display: flex; align-items: center; gap: 8px; font-size: 12px; }
    .dot { width: 10px; height: 10px; border-radius: 50%; }
    a { color: #6cb6ff; }
  </style>
</head>
<body>
  <h1>Memory Tracking Report</h1>
  <div class="muted">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
  <div class="muted">Window: $($start.ToString('yyyy-MM-dd HH:mm:ss')) → $($end.ToString('yyyy-MM-dd HH:mm:ss')) ($durationMin min)</div>
  <div class="muted">Source CSV: $CsvPath</div>

  <div class="grid" style="margin-top:14px;">
    <div class="card">
      <h2>Total PSS (KB) over time</h2>
      <canvas id="pssChart" width="1400" height="360"></canvas>
      <div id="pssLegend" class="legend"></div>
    </div>

    <div class="card">
      <h2>Total RSS (KB) over time</h2>
      <canvas id="rssChart" width="1400" height="360"></canvas>
      <div id="rssLegend" class="legend"></div>
    </div>

    <div class="card">
      <h2>Summary</h2>
      <table>
        <thead>
          <tr>
            <th>Package</th><th>Samples</th>
            <th>PSS Start</th><th>PSS End</th><th>PSS Min</th><th>PSS Max</th><th>PSS Avg</th>
            <th>RSS Start</th><th>RSS End</th><th>RSS Min</th><th>RSS Max</th><th>RSS Avg</th>
          </tr>
        </thead>
        <tbody>
          $statsRows
        </tbody>
      </table>
    </div>
  </div>

  <script>
    const series = $seriesJson;
    const colors = ['#6cb6ff','#8ddb8c','#f69d50','#d2a8ff','#ff7b72','#56d4dd'];

    function drawLineChart(canvasId, legendId, metricKey, titleY) {
      const canvas = document.getElementById(canvasId);
      const ctx = canvas.getContext('2d');
      const w = canvas.width, h = canvas.height;
      const pad = { l: 60, r: 20, t: 20, b: 40 };

      const pkgs = Object.keys(series);
      let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
      pkgs.forEach(pkg => {
        (series[pkg] || []).forEach(p => {
          minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
          const y = Number(p[metricKey] || 0);
          minY = Math.min(minY, y); maxY = Math.max(maxY, y);
        });
      });

      if (!isFinite(minX) || !isFinite(maxX)) return;
      if (minY === maxY) { maxY = minY + 1; }

      function sx(x){ return pad.l + (x-minX) * (w-pad.l-pad.r) / (maxX-minX || 1); }
      function sy(y){ return h-pad.b - (y-minY) * (h-pad.t-pad.b) / (maxY-minY || 1); }

      ctx.clearRect(0,0,w,h);
      ctx.strokeStyle = '#2a3a59';
      ctx.lineWidth = 1;
      for (let i=0;i<=5;i++) {
        const y = pad.t + i*(h-pad.t-pad.b)/5;
        ctx.beginPath(); ctx.moveTo(pad.l,y); ctx.lineTo(w-pad.r,y); ctx.stroke();
      }
      for (let i=0;i<=6;i++) {
        const x = pad.l + i*(w-pad.l-pad.r)/6;
        ctx.beginPath(); ctx.moveTo(x,pad.t); ctx.lineTo(x,h-pad.b); ctx.stroke();
      }

      ctx.fillStyle = '#9fb0c3';
      ctx.font = '12px Segoe UI';
      for (let i=0;i<=5;i++) {
        const v = maxY - i*(maxY-minY)/5;
        const y = pad.t + i*(h-pad.t-pad.b)/5;
        ctx.fillText(Math.round(v).toString(), 8, y+4);
      }
      for (let i=0;i<=6;i++) {
        const v = minX + i*(maxX-minX)/6;
        const x = pad.l + i*(w-pad.l-pad.r)/6;
        ctx.fillText(v.toFixed(1) + 'm', x-14, h-14);
      }

      ctx.fillStyle = '#9fb0c3';
      ctx.fillText(titleY, 8, 14);

      const legend = document.getElementById(legendId);
      legend.innerHTML = '';

      pkgs.forEach((pkg, idx) => {
        const c = colors[idx % colors.length];
        const pts = series[pkg] || [];
        if (!pts.length) return;
        ctx.strokeStyle = c;
        ctx.lineWidth = 2;
        ctx.beginPath();
        pts.forEach((p, i) => {
          const x = sx(p.x), y = sy(Number(p[metricKey] || 0));
          if (i === 0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
        });
        ctx.stroke();

        const item = document.createElement('div');
        item.className = 'legend-item';
        item.innerHTML = '<span class="dot" style="background:' + c + '"></span><span>' + pkg + '</span>';
        legend.appendChild(item);
      });
    }

    drawLineChart('pssChart', 'pssLegend', 'pss', 'PSS (KB)');
    drawLineChart('rssChart', 'rssLegend', 'rss', 'RSS (KB)');
  </script>
</body>
</html>
"@

$html | Out-File -FilePath $OutputHtml -Encoding utf8
Write-Host "Report generated: $OutputHtml"
