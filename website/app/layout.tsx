import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: '星象仪 · 把宇宙带到眼前',
  description:
    '星象仪项目介绍：探索星图、认识天体、模拟时间与观测位置，了解鸿蒙应用的开发与发布进展。',
  metadataBase: new URL('https://skyinstrument.cn'),
  robots: { index: true, follow: true },
  icons: { icon: '/app-icon.png' },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
