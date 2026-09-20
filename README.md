# DeepSeek Harness Windows 安装包

把 @deepseek-ai/dsh（DeepSeek Harness 的命令行程序）和一份便携版 Node.js 运行时打成一个单文件安装程序。
装完之后目标机器不需要预装 Node、npm 或任何依赖，双击快捷方式就能跑。

## 安装后是什么样

- 桌面和开始菜单各有「DeepSeek Harness」和「关闭 DeepSeek Harness」两个快捷方式
- 「DeepSeek Harness」启动 dsh web，服务起来后自动打开浏览器
- 「关闭 DeepSeek Harness」结束正在运行的服务
- 开始菜单文件夹里还有卸载入口，Windows 的「应用」列表里也能看到
- 图标用的是 dsh 前端自带的鲸鱼 favicon

按当前用户安装，不弹 UAC，默认目录：

    %LOCALAPPDATA%\Programs\DeepSeekHarness

向导里可以改成别的路径。

## 目录结构

    build\
      build.ps1        构建入口：取 dsh 包、下便携 Node、做图标、编译两个 exe、打安装包
      fetch-nsis.ps1   下载便携版 NSIS 3.11（SourceForge 镜像经常断，会换着试）
    src\
      Launcher.cs      启动器源码，产物 DeepSeekHarness.exe
      Stopper.cs       关闭器源码，产物 DeepSeekHarnessStop.exe
      installer.nsi    NSIS 安装脚本
      icon\
        whale.svg      图标源文件，取自 dsh 包内 dsh-web-frontend\dist\favicon.svg
        build-icon.js  用 dsh 自带的 sharp 把 svg 转成多尺寸 ico
    test\
      test-install.ps1 静默安装、逐项校验、启动关闭、真启动一次 dsh web、卸载，全流程
      fake-bin.js      假 bin.js，让启动器拉起一个常驻进程但不真起服务
      boot-check.js    用安装目录里的便携 node 真起一次 dsh web，校验 HTTP 200
    work\              构建中间产物（Node zip、staging、NSIS），可以删
    out\               构建产物 DeepSeekHarness-Setup-x.y.z.exe

## 构建环境

- Windows 10/11 x64
- PowerShell 5.1
- .NET Framework 4.x，用系统自带的 csc.exe 编译两个 exe：

      C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe

- Node.js，构建机上要有：跑图标脚本，同时从全局 npm 目录里取 dsh 包
- NSIS 3.x，没有的话 build.ps1 会自己下便携版到 work\nsis
- 联网，需要能访问 nodejs.org 和 SourceForge

项目路径别带空格，makensis 的命令行定义参数不吃空格。

## 构建

构建机上先装一份 dsh，脚本默认从这里取包：

    npm i -g @deepseek-ai/dsh

然后在项目根目录执行：

    powershell -ExecutionPolicy Bypass -File build\build.ps1

产物：

    out\DeepSeekHarness-Setup-0.1.1.exe      单文件，约 44 MB

可用参数：

- -DshSource <目录>   指定 dsh 包目录，默认 %APPDATA%\npm\node_modules\@deepseek-ai\dsh
- -NodeExe <路径>     构建机上的 node.exe，默认取 PATH 里的
- -AppVersion <版本>  覆盖版本号，默认从 dsh 的 package.json 取，0.1.1-rc.2 会取成 0.1.1
- -WorkDir / -OutDir  改中间目录和输出目录

work\ 里的东西会留着复用：Node zip 下过就不再下，NSIS 解出来的目录也保留。

## 测试

    powershell -ExecutionPolicy Bypass -File test\test-install.ps1

脚本会静默装到项目下的 testinstall\，逐项检查，再用安装目录里的便携 node 真起一次 dsh web（默认 3999 端口，避开常用的 3080），最后自己卸掉。

输出是一串 ### 开头的检查行，最后一行是 ALL CHECKS PASSED 或者失败条数。

注意一点：测试用的快捷方式名和正式安装完全一样，跑测试会把当前用户的桌面和开始菜单快捷方式改成指向 testinstall\，卸载阶段又删掉。测完想要恢复正式安装，再静默装一次默认目录：

    out\DeepSeekHarness-Setup-0.1.1.exe /S

## 实现上踩过的坑

- installer.nsi 必须存成 UTF-8 BOM 或 UTF-16LE，否则 NSIS 直接报 Bad text encoding。仓库里这份是 UTF-8（无 BOM），build.ps1 编译前会转成 UTF-16LE 再交给 makensis。

- NSIS 卸载器会把自己复制到 %TEMP% 再执行，原进程立刻退出。所以外部脚本不能「等进程结束」就认定卸载完成，得轮询目录是否消失，test-install.ps1 里有现成写法。

- 启动器拉起 dsh 后不退出，留在后台当宿主进程：把 dsh 的 stdout/stderr 泵进 run.log，并守到 dsh 退出。如果拉起来就撤，父进程一退管道就断，dsh 之后写日志会 EPIPE。

- 同一台机器上已经有一份 dsh 在跑（默认 3080 端口）时，再双击启动器不会起第二个：pid 文件里的进程还活着，就直接打开已在运行的页面。

- 便携 Node 的版本要和 dsh 依赖里的原生模块对得上（node-pty、sharp、koffi 这些），构建脚本默认跟构建机的 node 版本一致。

- 打包时删掉了 node-pty 的 darwin/linux/arm64 预编译和 sharp 的 wasm 版本，省下约 30 MB，这些在 Windows x64 上不会被加载。

## 运行期文件

    %LOCALAPPDATA%\DeepSeekHarness\pid.txt    正在运行的 dsh 进程号，关闭器靠它定位
    %LOCALAPPDATA%\DeepSeekHarness\run.log    dsh 的标准输出和错误输出

启动失败时会弹窗把 run.log 的路径告诉你。

## 许可

dsh 本体是 MIT 许可，见 dsh 包里的 LICENSE。这里的安装包脚本同样以 MIT 发布。鲸鱼图标来自 dsh 包内的前端资源，版权归 DeepSeek。
