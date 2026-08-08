# MSVC Build Fix — V3.8.1

## 问题

Windows / Visual Studio 2022 构建 V3.8 时，`sand_simulation.cpp` 的 `set_flow_states()` 中存在：

```cpp
const int count = std::min(4097, states.size());
```

`PackedInt32Array::size()` 在 godot-cpp 中返回 `int64_t`，而 `4097` 是 `int`。MSVC 的 `std::min()` 要求两个模板实参推导为相同类型，因此报 C2672，并连带导致 `count` 的 C2737。

## 修复

改为：

```cpp
const int count = std::min(4097, static_cast<int>(states.size()));
```

Flow State 表固定最多 4097 项，因此该转换不会造成截断风险。

## 兼容性

本修复仅影响编译类型推导，不改变 Native 接口或运行逻辑。

```text
Native API = 9
```

重新构建后 F1 仍应显示：

```text
native yes(api 9)
Native flow: yes
```

## 构建

```bat
cd extensions\sand-slide
build_windows_collision_sectors.bat
```
