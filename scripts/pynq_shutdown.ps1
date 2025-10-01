$port  = [System.IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One');
$port.Open()
Start-Sleep -Milliseconds 500           # wait prompt
$port.WriteLine('sudo shutdown -h now')
Start-Sleep -Milliseconds 300           # wait prompt
$port.WriteLine('xilinx')
Start-Sleep 1
$port.Close()
