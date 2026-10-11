export default function Credits() {
  return (
    <main className="prose">
      <a href="/">← 返回星象仪</a>
      <h1>开源与致谢</h1>
      <p>
        星象仪基于 Stellarium 开源天文软件进行鸿蒙平台适配。感谢 Stellarium
        开发者、译者、天空文化贡献者与各类天文数据的提供者。
      </p>
      <h2>源码与许可证</h2>
      <p>
        <a
          href="https://github.com/joinother/stellarium"
          target="_blank"
          rel="noopener noreferrer"
        >
          星象仪适配项目源码
        </a>{' '}
        ·{' '}
        <a
          href="https://stellarium.org/"
          target="_blank"
          rel="noopener noreferrer"
        >
          Stellarium 上游项目
        </a>
      </p>
      <p>
        软件、图片、天空文化和数据集可能采用不同许可证，请以源文件、上游资源说明和应用中的开源信息为准。本网站不改变、覆盖或替代这些授权要求。
      </p>
      <h2>网站视觉</h2>
      <p>
        首页交互星群为本项目编写的程序化艺术示意，并非真实观测数据，也未使用
        OpenAI
        的图像、标识或页面代码。应用截图由项目维护者提供，保留原始界面内容。
      </p>
      <h2>网站组件</h2>
      <p>
        网站使用 React、vinext 与 Lucide
        图标等开源组件。依赖版本记录在网站锁文件中；正式分发前应随构建产物保存依赖许可清单。
      </p>
    </main>
  );
}