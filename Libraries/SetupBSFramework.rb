# Supported extra options:
# physicsModule: specify the physics module
# audioModule: specify the audio module
# renderAPI: specify the primary render API
# buildAllRenderAPI: if true build all render modules at once
class BSFramework < StandardCMakeDep
  def initialize(args)
    super('bs::framework', 'bsf', args)

    @Options.push "-DPHYSICS_MODULE=#{args[:physicsModule]}" if args.include? :physicsModule

    @Options.push "-DAUDIO_MODULE=#{args[:audioModule]}" if args.include? :audioModule

    @Options.push "-DRENDER_API_MODULE=#{args[:renderAPI]}" if args.include? :renderAPI

    if args.include? :buildAllRenderAPI
      @Options.push "-DBUILD_ALL_RENDER_API=#{args[:buildAllRenderAPI]}"
    end

    if args.include? :extraLibSearch
      @Options.push "-DDYNLIB_EXTRA_SEARCH_DIRECTORY=#{args[:extraLibSearch]}"
    end

    @Options.push '-DBSF_ENABLE_EXCEPTIONS=ON'
    @Options.push '-DBSF_ENABLE_RTTI=ON'
    @Options.push '-DBSF_STRIP_DEBUG_INFO=OFF'

    self.HandleStandardCMakeOptions

    @RepoURL ||= 'https://github.com/GameFoundry/bsf.git'
  end

  def depsList
    os = getLinuxOS

    if os == 'fedora' || os == 'centos' || os == 'rhel'

      return [
        'vulkan-headers', 'vulkan-loader', 'vulkan-loader-devel', 'vulkan-tools',
        'vulkan-validation-layers', 'libuuid-devel', 'libX11-devel', 'libXcursor-devel',
        'libXrandr-devel', 'libXi-devel', 'mesa-libGLU-devel'
      ]

    end

    if os == 'ubuntu'

      return [
        'libvulkan-dev', 'vulkan-tools', 'vulkan-validationlayers', 'uuid-dev', 'libx11-dev',
        'libxcursor-dev', 'libxrandr-dev', 'libxi-dev', 'libglu1-mesa-dev'
      ]
    end

    onError "#{@name} unknown packages for os: #{os}"
  end

  def installPrerequisites
    installDepsList depsList
  end

  def translateBuildType(type)
    if type == 'Debug'
      'Debug'
    else
      'Release'
    end
  end

  def DoClone
    runSystemSafe('git', 'clone', @RepoURL) == 0
  end

  def DoUpdate
    standardGitUpdate
  end

  def getInstalledFiles
    if OS.windows?
      [
        # data files
        'bin/Data',

        # includes
        'include/bsfUtility',
        'include/bsfCore',
        'include/bsfEngine',

        # libraries
        'bin/bsfVulkanRenderAPI.dll',
        'lib/bsf.lib',
        'lib/bsfD3D11RenderAPI.lib',
        'lib/bsfFBXImporter.lib',
        'lib/bsfFontImporter.lib',
        'lib/bsfFreeImgImporter.lib',
        'lib/bsfGLRenderAPI.lib',
        'lib/bsfNullAudio.lib',
        'lib/bsfNullPhysics.lib',
        'lib/bsfRenderBeast.lib',
        'lib/bsfSL.lib',
        'lib/bsfVulkanRenderAPI.lib',

        # dlls
        'bin/bsf.dll',
        'bin/bsfD3D11RenderAPI.dll',
        'bin/bsfFBXImporter.dll',
        'bin/bsfFontImporter.dll',
        'bin/bsfFreeImgImporter.dll',
        'bin/bsfGLRenderAPI.dll',
        'bin/bsfNullAudio.dll',
        'bin/bsfNullPhysics.dll',
        'bin/bsfRenderBeast.dll',
        'bin/bsfSL.dll',

        # executables
        'bin/bsfImportTool.exe'
      ]
    elsif OS.linux?
      [
        # data files
        'bin/Data',

        # includes
        'include/bsfUtility',
        'include/bsfCore',
        'include/bsfEngine',

        # libraries
        'lib/libbsfFBXImporter.so',
        'lib/libbsfFontImporter.so',
        'lib/libbsfFreeImgImporter.so',
        'lib/libbsfGLRenderAPI.so',
        'lib/libbsfNullAudio.so',
        'lib/libbsfNullPhysics.so',
        'lib/libbsfRenderBeast.so',
        'lib/libbsfSL.so',
        'lib/libbsf.so',
        'lib/libbsfVulkanRenderAPI.so'
      ]
    end
  end
end
