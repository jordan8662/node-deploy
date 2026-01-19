# x1为源路径， x2为欲排除的文件/目录，x3为目标路径
ls .local/ | grep -v node1 node2 node3  | xargs -i cp -r x1/{} x3/   

### 选重列
shift + Alt + 鼠标左键拖动;
