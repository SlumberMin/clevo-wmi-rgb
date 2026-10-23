# clevo-wmi-rgb — 蓝天/Clevo 笔记本键盘背光 WMI 协议

对 **七彩虹 X15 AT23（蓝天 Clevo NP50SNE 模具）** 键盘背光的逆向研究记录。
通过 `root\WMI` 下的 `CLEVO_GET.SetKBLED(uint32)` 控制颜色，实测可用（需要管理员）。

> **推广性说明（重点）**
>
> 本机 DMI 模具串是 `NP5x_6x_7x_SNx`。蓝天（Clevo）多代模具的 ACPI/WMI 接口都叫 `CLEVO_GET`，
> `SetKBLED` 与下面这套 magic values **很可能**也能用于其它蓝天/Clevo 模具的笔记本（NP5x / NP6x / NP7x 等），
> 但**本仓库没有在其它机型上实验过**，属于未验证推测。
>
> 已知差异点：
> - 本机协议虽然支持 left / mid / right 分区，但**实测整块键盘只有一个颜色**（单区）；别的模具可能是真分区。
> - 不同模具的亮度级数、灯条支持、magic values 可能不同（例如 clevomanager 的模型配置表里就有多套值）。
> - 必须管理员权限；普通权限调用会被拒绝。
>
> 在别的机型上验证前，请先读 [docs/PROTOCOL.md](docs/PROTOCOL.md) 的“推广验证步骤”和风险说明。

## 快速事实

| 项 | 值 |
|---|---|
| 命名空间 | `root\WMI` |
| 类 | `CLEVO_GET` |
| 实例 | `ACPI\PNP0C14\0_0` |
| 方法 | `SetKBLED(uint32 value)` |
| 权限 | **管理员** |
| 颜色打包 | `(B << 16) + (R << 8) + G`（注意是 B-R-G 顺序，不是 RGB） |
| 分区基址 | left `0xF0000000` / mid `0xF1000000` / right `0xF2000000` / lightbar `0xF3000000` |
| 开灯 | `0xE007F007` |
| 亮度 | `0xF4000000 \| level`（off 0 / low 63 / mid 127 / high 255） |

Excel 例子：左区纯红 = `0xF000FF00`。

## 验证

```powershell
# 1) 类是否存在（非管理员会返回“拒绝访问”，这代表类存在、只是没权限）
Get-CimInstance -Namespace root\WMI -Class CLEVO_GET -ErrorAction Stop | Select InstanceName

# 2) 点灯测试（管理员终端）
powershell -ExecutionPolicy Bypass -File .\tools\clevo_probe.ps1 -Apply -Color FF0000
```

`tools/clevo_probe.ps1` 只做两件事：列出类、可选取一个颜色下发。默认不改任何东西。

注册 WMI 类通常需要把厂商的 `CLEVOMOF.dll` 拷到 `System32`/`SysWOW64` 并在
`HKLM\SYSTEM\CurrentControlSet\Control\WMI\WmiAcpi` 下写 `MofImagePath`。
`tools/register_clevo.ps1` 是当时的注册脚本，但**仓库不包含 `CLEVOMOF.dll`**（厂商二进制），
需要你自己从官方驱动包提取。

## 相关仓库

- 灯效软件：[PrismSync](https://github.com/SlumberMin/PrismSync)
- 同系列研究：[aula-hero68-protocol](https://github.com/SlumberMin/aula-hero68-protocol) ·
  [mchose-v9-protocol](https://github.com/SlumberMin/mchose-v9-protocol)

## License / 免责

代码 MIT，文档 CC BY 4.0。与七彩虹、蓝天（Clevo）无关联；逆向研究仅供学习，刷写硬件风险自负。
