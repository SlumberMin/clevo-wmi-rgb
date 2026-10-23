# Clevo WMI 键盘背光协议（实测记录）

测试机：**七彩虹 X15 AT23**，DMI 模具 `NP5x_6x_7x_SNx`（蓝天 Clevo NP50SNE）。

## 1. 接口

```
命名空间  root\WMI
类        CLEVO_GET
实例      ACPI\PNP0C14\0_0
方法      SetKBLED(uint32)
权限      管理员（非管理员调用 → 拒绝访问）
```

查询示例（管理员）：

```powershell
Get-CimInstance -Namespace root\WMI -Class CLEVO_GET | Select InstanceName
# ACPI\PNP0C14\0_0
```

调用示例（PowerShell，命令行的 `$o.SetKBLED()` 与 C# 的 `ManagementObject.InvokeMethod` 等价）：

```powershell
$o = Get-WmiObject -Namespace root\WMI -Class CLEVO_GET
$o.SetKBLED(0xF000FF00)   # 左区纯红
```

> 直接调用 `SetKBLED` 是毫秒级的阻塞操作，做动画时不要放在 30 fps 主循环里同步调用，
> 应使用“单槽位 + 后台线程”异步下发（见 PrismSync 的 `ClevoDevice.cs`）。

## 2. 参数编码

基础分区值（低 16 位留给亮度/颜色）：

| 用途 | 值 |
|---|---|
| 开灯 | `0xE007F007` |
| 关灯 | `0xE0003000` |
| 左区 | `0xF0000000` |
| 中区 | `0xF1000000` |
| 右区 | `0xF2000000` |
| 灯条 | `0xF3000000` |
| 亮度 | `0xF4000000 \| level`（0 / 63 / 127 / 255） |

颜色按 **B、R、G** 顺序打包成 24 位：

```
value = part | (B << 16) | (R << 8) | G
```

例：

| 目标 | value |
|---|---|
| 左区纯红 `(255,0,0)` | `0xF000FF00` |
| 左区纯绿 `(0,255,0)` | `0xF00000FF` |
| 左区纯蓝 `(0,0,255)` | `0xF0FF0000` |
| 中区 `(0,160,255)` | `0xF1FF00A0` |

## 3. 本机行为

- 协议**接受** left / mid / right 三个分区值，但本机所有键一起亮：**实际是全局单色**。
  因此驱动里把笔记本当作单区设备处理，取效果在桌面轴中点处的颜色。
- 亮度 `0xF4000000 | 255` 设置为高；亮度值会保持。
- 关闭程序后设备保持最后一次颜色（硬件行为，不是后台进程）。

## 4. 推广到其它蓝天/Clevo 模具（未实验）

**结论：很可能是同一套 WMI + magic values，但没有在 NP50SNE 之外的机器上验证过。**

支持这个推测的证据：

1. `CLEVO_GET` / `SetKBLED` 是蓝天 EC ACPI 驱动使用的公共 WMI 接口，多个开源项目
   （如 clevomanager）在多个蓝天模具上用过同类接口。
2. 本机 DMI 模具串是 `NP5x_6x_7x_SNx`，说明厂商驱动本身是按“NP5x/6x/7x”多代共用一套配置的。

已知可能不同的地方：

- **分区**：别的模具可能真的是 left/mid/right 分区，而本机是全局单色；
- **灯条**（lightbar）可能有或没有；
- **亮度级数**可能不是 0/63/127/255；
- 极少数机型可能需要不同的 magic（clevomanager 的模型表里有多个变体）。

### 安全的验证步骤

1. 管理员终端，先只读查询：

   ```powershell
   Get-CimInstance -Namespace root\WMI -Class CLEVO_GET | Select InstanceName
   ```

   - 返回实例 → 类存在，可以继续；
   - 返回“拒绝访问” → 类存在但没提权，用管理员重试；
   - 返回“无效类/未找到” → 该机型没有这个 WMI 类，本方案不适用。

2. 记录当前颜色/亮度（截图），准备恢复：把亮度设回原值、颜色设回原色。

3. 先测开灯/亮度这类非破坏性值：

   ```powershell
   $o = Get-WmiObject -Namespace root\WMI -Class CLEVO_GET
   $o.SetKBLED(0xF40000FF)   # 亮度 high
   ```

4. 再测单一分区颜色（从 `0xF000FF00` 左区红开始），观察是“只亮左区”还是“全键盘一起变”：
   - 全键盘 → 单区，按本仓库的方式用；
   - 只亮一区 → 真分区，可以按 left/mid/right 分别映射效果，比本项目更细。

5. 如果颜色/分区完全没反应，检查：
   - 是否管理员；
   - 是否被厂商控制中心/其它 RGB 软件持续抢占；
   - 是否该机型把键盘灯挂在别的 EC 通道（部分蓝天机型的灯控在 `CLEVO_GET` 之外）。

### 风险

- 这是写 EC/WMI 的私有接口，**没有官方文档**；理论上存在把背光亮度/状态写乱的可能。
  已知值都是可逆的（重设亮度/颜色即可恢复），但请自行评估风险。
- 不要在非自己的机器上试。

## 5. 参考实现

PrismSync `native/src/Devices/ClevoDevice.cs`：

- 后台线程只做 `SetKBLED`；
- 主线程只把最新颜色写入一个槽位，中间帧直接丢弃；
- 打开时先设亮度 high，再开灯；
- 非管理员时直接给出明确错误，不反复重试。

MIT License · 文档 CC BY 4.0
