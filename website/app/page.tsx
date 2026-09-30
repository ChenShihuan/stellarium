import {
  ArrowDown,
  ArrowUpRight,
  Compass,
  Orbit,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';
import Galaxy from '@/components/galaxy';

const source = 'https://github.com/joinother/stellarium';

export default function Home() {
  return (
    <>
      <a className="skip-link" href="#main">
        跳到正文
      </a>
      <header className="site-header">
        <a className="wordmark" href="#top" aria-label="星象仪，回到首页">
          <Sparkles aria-hidden="true" size={24} />
          <span>星象仪</span>
        </a>
        <nav aria-label="主导航">
          <a href="#explore">探索</a>
          <a href="#experience">应用体验</a>
          <a href="#about">关于</a>
        </nav>
        <a className="header-link" href="#availability">
          发布进展 <ArrowUpRight size={15} aria-hidden="true" />
        </a>
      </header>
      <main id="main">
        <section className="hero" id="top" aria-labelledby="hero-title">
          <Galaxy />
          <div className="hero-copy">
            <p className="eyebrow">SKY INSTRUMENT · 星象仪</p>
            <h1 id="hero-title">
              把宇宙，
              <br />
              带到眼前。
            </h1>
            <p className="hero-description">
              从身边的一颗星，到遥远的银河。
              <br />
              在你的设备上，重新认识头顶这片天空。
            </p>
            <a className="pill primary" href="#explore">
              开启探索 <ArrowDown size={17} aria-hidden="true" />
            </a>
          </div>
          <div className="hero-bottom">
            <span>为好奇心，留一片星空。</span>
            <span>01 — 无限，从抬头开始</span>
          </div>
        </section>
        <section className="intro section" id="explore">
          <p className="eyebrow">一片天空，不止一种看法</p>
          <div className="section-heading">
            <h2>
              不只是认出星星。
              <br />
              <span>更是走近它们。</span>
            </h2>
            <p>
              滑动星图，让视线穿过星座。调整时间，看日夜交替。点开一颗星，了解它的坐标、距离与故事。
            </p>
          </div>
          <figure className="sky-preview">
            <img
              src="/images/sky.jpg"
              alt="星象仪实际星图界面：夜空、流星雨辐射点、方位标记与底部操作栏"
              width="2560"
              height="1600"
              loading="lazy"
              decoding="async"
            />
            <figcaption>
              <span>你的随身星空</span>
              <span>应用实际截图 · 界面以发布版本为准</span>
            </figcaption>
          </figure>
          <div className="feature-grid">
            <article>
              <Compass aria-hidden="true" />
              <h3>找到，眼前那颗星</h3>
              <p>
                浏览星图、搜索天体、查看观测坐标，让肉眼所见与天文知识连接起来。
              </p>
            </article>
            <article>
              <Orbit aria-hidden="true" />
              <h3>让时间，成为视角</h3>
              <p>改变观测时间与位置，预览天空的变化，为下一次抬头做好准备。</p>
            </article>
            <article>
              <Sparkles aria-hidden="true" />
              <h3>看见，更多的宇宙</h3>
              <p>
                从行星到深空天体，从星座连线到天空文化，在同一片星空中继续探索。
              </p>
            </article>
          </div>
        </section>
        <section className="experience section" id="experience">
          <div className="experience-copy">
            <p className="eyebrow">细看一颗星</p>
            <h2>
              好奇心，
              <br />
              有了落脚点。
            </h2>
            <p>
              星等、距离、所在星座与实时方位，在一张详情卡片里展开。把抽象的天体，变成可以慢慢了解的世界。
            </p>
            <p className="fine-print">
              三维示意用于辅助理解，不等同于望远镜实拍；资料完整度取决于对应的本地目录。
            </p>
          </div>
          <figure>
            <img
              src="/images/details.jpg"
              alt="星象仪奎宿九详情卡片，展示星等、仙女座归属、距离和三维示意"
              width="2560"
              height="1600"
              loading="lazy"
              decoding="async"
            />
            <figcaption>一颗星的资料，也可以直观易读。</figcaption>
          </figure>
        </section>
        <section className="principles section" id="about">
          <p className="eyebrow">关于这个项目</p>
          <h2>
            探索很远。
            <br />
            <span>体验，离你很近。</span>
          </h2>
          <div className="principle-list">
            <article>
              <span>01</span>
              <div>
                <h3>离线，也能仰望</h3>
                <p>
                  以本地星图和随应用打包的资料为基础。在线资源更新仍在筹备，不把尚未上线的服务当作现有能力。
                </p>
              </div>
              <ShieldCheck aria-hidden="true" />
            </article>
            <article>
              <span>02</span>
              <div>
                <h3>从开源出发，继续探索</h3>
                <p>
                  基于 Stellarium
                  开源项目进行鸿蒙适配。尊重原作者、资料来源和各项开源许可。
                </p>
                <a href={source} target="_blank" rel="noopener noreferrer">
                  查看项目源码 <ArrowUpRight size={15} aria-hidden="true" />
                </a>
              </div>
            </article>
            <article>
              <span>03</span>
              <div>
                <h3>不同设备，同一份好奇</h3>
                <p>
                  围绕触摸操作与响应式布局，打磨手机和平板上的星图体验。设备支持情况以最终上架信息为准。
                </p>
              </div>
            </article>
          </div>
        </section>
        <section className="availability section" id="availability">
          <p className="eyebrow">个人开源作品 · 持续完善</p>
          <h2>
            星空已在眼前。
            <br />
            探索，仍在继续。
          </h2>
          <p>
            网站备案已通过，星象仪持续开发与完善。
            <br />
            应用市场详情页以正式发布状态为准，设备兼容性以应用市场为准。
          </p>
          <div className="availability-actions">
            <a
              className="pill primary"
              href="https://appgallery.huawei.com/app/detail?id=com.joinother.skyinstrument"
              target="_blank"
              rel="noopener noreferrer"
            >
              打开华为应用市场 <ArrowUpRight size={17} aria-hidden="true" />
            </a>
            <a
              className="pill secondary"
              href={`${source}/issues`}
              target="_blank"
              rel="noopener noreferrer"
            >
              反馈与交流 <ArrowUpRight size={17} aria-hidden="true" />
            </a>
          </div>
          <p className="fine-print">
            如果设备未直接打开详情页，请在华为应用市场搜索“星象仪”。该入口使用应用包名
            App Linking，不代表华为认证或推荐。
          </p>
          <p className="fine-print">反馈与交流跳转至 GitHub；当前页面不提供安装包或在线资源下载。</p>
        </section>
      </main>
      <footer>
        <div className="footer-top">
          <a className="wordmark" href="#top">
            <Sparkles aria-hidden="true" size={22} />
            星象仪
          </a>
          <span>同一片星空，共同的好奇。</span>
        </div>
        <div className="footer-bottom">
          <span>skyinstrument.cn · 个人开源作品</span>
          <div>
            <a href="https://beian.miit.gov.cn/" target="_blank" rel="noopener noreferrer">新ICP备2026008516号-1</a>
            <a href="/privacy/">隐私说明</a>
            <a href="/credits/">开源与致谢</a>
            <a href="#availability">发布状态</a>
          </div>
        </div>
      </footer>
    </>
  );
}
