#!/bin/bash
# filepath: /home/lin/文档/termux-packages/build_source.sh

# 定义基础目录（当前项目目录下的 debian-repo 子目录）
REPO_DIR="$(pwd)/debian-repo"

# 清理原有目录（如果存在）
rm -rf "$REPO_DIR"

# 创建主目录
mkdir -p "$REPO_DIR"
echo "创建仓库目录: $REPO_DIR"

# 只创建 aarch64 架构子目录
mkdir -p "$REPO_DIR/dists/stable/"{main,contrib,non-free}/binary-aarch64

# 创建软件包目录
mkdir -p "$REPO_DIR/pool/main"
mkdir -p "$REPO_DIR/pool/contrib"
mkdir -p "$REPO_DIR/pool/non-free"

echo "目录结构已创建完成"

# 从当前项目的 debs 目录复制 deb 文件到 pool 目录
if [ -d "$(pwd)/debs" ]; then
    echo "正在复制 deb 文件..."
    # 只复制 aarch64 架构的包
    if [ -d "$(pwd)/debs/aarch64" ]; then
        cp $(pwd)/debs/aarch64/*.deb "$REPO_DIR/pool/main/" 2>/dev/null || echo "没有找到 aarch64 的 deb 文件"
    fi
elif [ -d "$(pwd)/output_release" ]; then
    echo "正在从 output_release 目录复制 deb 文件..."
    find "$(pwd)/output_release" -name "*.deb" -exec cp {} "$REPO_DIR/pool/main/" \; 2>/dev/null
    deb_count=$(find "$REPO_DIR/pool/main/" -name "*.deb" | wc -l)
    echo "复制了 $deb_count 个 deb 文件"
else
    echo "警告: 未找到 debs 或 output_release 目录，请手动将 deb 文件复制到 $REPO_DIR/pool/main/"
fi

# 修改 Dockerfile 直接在内部设置代理，避免构建时设置
echo "创建 Dockerfile..."
cat > "$REPO_DIR/Dockerfile" << 'EOF'
FROM debian:bullseye-slim

# 设置代理
ENV HTTP_PROXY="http://host.docker.internal:7890"
ENV HTTPS_PROXY="http://host.docker.internal:7890"
ENV http_proxy="http://host.docker.internal:7890"
ENV https_proxy="http://host.docker.internal:7890"
ENV all_proxy="socks5://host.docker.internal:7891"
ENV NO_PROXY="localhost,127.0.0.1"
ENV no_proxy="localhost,127.0.0.1"

RUN apt-get update && apt-get install -y \
    dpkg-dev \
    apt-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /repo

CMD bash -c '\
    # 只处理 aarch64 架构 \
    arch="aarch64"; \
    for section in main contrib non-free; do \
        mkdir -p "dists/stable/$section/binary-$arch"; \
        dpkg-scanpackages -m "pool/$section" > "dists/stable/$section/binary-$arch/Packages" 2>/dev/null || echo "没有找到 $section 的软件包"; \
        gzip -k -f "dists/stable/$section/binary-$arch/Packages" 2>/dev/null || true; \
    done && \
    cd dists/stable && \
    apt-ftparchive release . > Release'
EOF

echo "构建 Docker 镜像..."
# 使用宿主机网络
docker build \
    --add-host=host.docker.internal:host-gateway \
    --network=host \
    -t debian-repo-builder "$REPO_DIR"

echo "运行 Docker 容器，生成仓库文件..."
docker run --rm \
    --add-host=host.docker.internal:host-gateway \
    --network=host \
    -v "$REPO_DIR":/repo debian-repo-builder

# 创建一个简单的 index.html 文件
cat > "$REPO_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Termux aarch64 软件源</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; margin: 0 auto; max-width: 800px; padding: 20px; }
        h1 { color: #4a86e8; }
        h2 { color: #6aa84f; }
        pre { background-color: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>Termux aarch64 软件源</h1>
    <p>这是一个专为 aarch64 架构设计的 Debian 软件源。</p>
    
    <h2>使用方法</h2>
    <p>在 Debian/Ubuntu 系统中，添加以下行到 <code>/etc/apt/sources.list.d/termux.list</code> 文件：</p>
    <pre>deb [trusted=yes arch=aarch64] http://服务器IP:端口/ stable main</pre>
    
    <p>然后更新软件包索引：</p>
    <pre>sudo apt update</pre>
    
    <h2>仓库结构</h2>
    <ul>
        <li><a href="dists/">dists/</a> - 分发目录</li>
        <li><a href="pool/">pool/</a> - 软件包存储区</li>
    </ul>
</body>
</html>
EOF

echo "仓库已创建完成，位于: $REPO_DIR"
echo "您可以使用以下命令启动一个临时的 HTTP 服务器来测试：cd $REPO_DIR && python -m http.server 8080"
echo "然后在浏览器中访问 http://localhost:8080 查看仓库"