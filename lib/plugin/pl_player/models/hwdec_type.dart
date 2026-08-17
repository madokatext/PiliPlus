// mpv --hwdec=help
enum HwDecType {
  no('no', '解封CPU 硬扛，这把高端局'),
  auto('auto', '解封任意可用赛博拆包器'),
  autoSafe('auto-safe', '解封最佳赛博拆包器'),
  autoCopy('auto-copy', '解封带拷贝功能的最佳赛博拆包器，这把高端局'),
  d3d12va('d3d12va', 'DirectX 12 (Windows10 及以上)，优势在我'),
  d3d12vaCopy('d3d12va-copy', 'DirectX 12 (Windows10 及以上) (非直通)，包的'),
  d3d11va('d3d11va', 'DirectX 11 (Windows8 及以上)，曼波'),
  d3d11vaCopy('d3d11va-copy', 'DirectX 11 (Windows8 及以上) (非直通)，曼波'),
  dxva2('dxva2', 'DXVA2 (Windows7 及以上)，优势在我'),
  dxva2Copy('dxva2-copy', 'DXVA2 (Windows7 及以上) (非直通)，我嘞个豆'),
  videotoolbox('videotoolbox', 'VideoToolbox (macOS / iOS)'),
  videotoolboxCopy('videotoolbox-copy', 'VideoToolbox (macOS / iOS) (非直通)，启动！'),
  vaapi('vaapi', 'VAAPI (Linux)'),
  vaapiCopy('vaapi-copy', 'VAAPI (Linux) (非直通)，不是哥们'),
  nvdec('nvdec', 'NVDEC (NVIDIA独占)，曼波'),
  nvdecCopy('nvdec-copy', 'NVDEC (NVIDIA独占) (非直通)，CPU 都看沉默了'),
  drm('drm', 'DRM (Linux)'),
  drmCopy('drm-copy', 'DRM (Linux) (非直通)，鼠鼠我啊'),
  vulkan('vulkan', 'Vulkan (全平台) (实验性)，我嘞个豆'),
  vulkanCopy('vulkan-copy', 'Vulkan (全平台) (实验性) (非直通)，不是哥们'),
  vdpau('vdpau', 'VDPAU (Linux)'),
  vdpauCopy('vdpau-copy', 'VDPAU (Linux) (非直通)，已老实'),
  mediacodec('mediacodec', 'MediaCodec (Android)'),
  mediacodecCopy('mediacodec-copy', 'MediaCodec (Android) (非直通)，这把高端局'),
  cuda('cuda', 'CUDA (NVIDIA独占) (过时)，优势在我'),
  cudaCopy('cuda-copy', 'CUDA (NVIDIA独占) (过时) (非直通)，属实绷不住'),
  crystalhd('crystalhd', 'CrystalHD (全平台) (过时)，曼波'),
  rkmpp('rkmpp', 'Rockchip MPP (仅部分Rockchip芯片)，包的'),
  amf('amf', 'AMF (AMD独占)，我嘞个豆'),
  amfCopy('amf-copy', 'AMF (AMD独占) (非直通)，功德+1'),
  qsv('qsv', 'Quick Sync Video (Intel独占)，启动！'),
  qsvCopy('qsv-copy', 'Quick Sync Video (Intel独占) (非直通)，这把高端局'),
  ;

  final String hwdec;
  final String desc;
  const HwDecType(this.hwdec, this.desc);

  static final String androidDefault = [
    HwDecType.mediacodec.hwdec,
    HwDecType.autoSafe.hwdec,
  ].join(',');
}
