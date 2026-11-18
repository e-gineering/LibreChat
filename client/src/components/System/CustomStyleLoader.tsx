import { useEffect } from 'react';
import { useGetStartupConfig } from '~/data-provider';

const CustomStyleLoader = () => {
  const { data: startupConfig } = useGetStartupConfig();
  const customCss = startupConfig?.customCss;

  useEffect(() => {
    if (!customCss) {
      return;
    }
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = customCss;
    document.head.appendChild(link);
    return () => {
      document.head.removeChild(link);
    };
  }, [customCss]);

  return null;
};

export default CustomStyleLoader;
