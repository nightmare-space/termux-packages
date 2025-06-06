#!/bin/bash
# 分析目录中所有deb包的依赖关系

DEBS_DIR="./output"  # 存放deb文件的目录
DEPENDENCY_MAP={}
ALL_PACKAGES=()

# 获取所有deb文件名
for deb in "$DEBS_DIR"/*.deb; do
    package_name=$(basename "$deb" | sed -E 's/^([^_]+).*/\1/')
    ALL_PACKAGES+=("$package_name")
    
    # 获取依赖信息
    deps=$(dpkg -I "$deb" | grep "Depends:" | sed 's/Depends://g' | tr ',' '\n' | sed 's/([^)]*)//g' | sed 's/ //g')
    
    echo "包 $package_name 依赖于:"
    for dep in $deps; do
        if [[ ! "$dep" =~ "|" ]]; then  # 忽略可选依赖
            dep_name=$(echo "$dep" | sed 's/\(.*\)[<>=].*/\1/')
            echo "  - $dep_name"
        fi
    done
    echo ""
done

# 检查哪些依赖不在我们的包列表中
echo "缺失的依赖:"
for deb in "$DEBS_DIR"/*.deb; do
    package_name=$(basename "$deb" | sed -E 's/^([^_]+).*/\1/')
    deps=$(dpkg -I "$deb" | grep "Depends:" | sed 's/Depends://g' | tr ',' '\n' | sed 's/([^)]*)//g' | sed 's/ //g')
    
    for dep in $deps; do
        if [[ ! "$dep" =~ "|" ]]; then  # 忽略可选依赖
            dep_name=$(echo "$dep" | sed 's/\(.*\)[<>=].*/\1/')
            
            # 检查是否在我们的包列表中
            found=false
            for p in "${ALL_PACKAGES[@]}"; do
                if [[ "$p" == "$dep_name" ]]; then
                    found=true
                    break
                fi
            done
            
            if ! $found; then
                echo "$package_name 需要 $dep_name (缺失)"
            fi
        fi
    done
done