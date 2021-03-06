# Ogre must be installed for this to work, or the Ogre location needs to be provided
# through extra options
# Supported extra options:
# TODO: component configuration
# On windows requires the FreeType dependency to be built before
class CEGUI < BaseDep
  def initialize(args)
    super("CEGUI", "cegui", args)

    self.HandleStandardCMakeOptions

    if @PythonBindings
      @Options.push "-DCEGUI_BUILD_PYTHON_MODULES=ON"
    else
      @Options.push "-DCEGUI_BUILD_PYTHON_MODULES=OFF"
    end

    if OS.windows?
      # TODO: pass some arguments from args?
      @CEGUIWinDeps = CEGUIDependencies.new(self, {installPath:
                                                     File.join(@Folder, "dependencies")})
    end

    if !@RepoURL
      @RepoURL = "https://bitbucket.org/cegui/cegui"
    end
    
  end

  def depsList
    os = getLinuxOS

    if os == "fedora" || os == "centos" || os == "rhel"
      return [
        "glm-devel"
      ]
    end

    if os == "ubuntu"
      return [
        "libglm-dev"
      ]
    end
    
    onError "#{@name} unknown packages for os: #{os}"
  end

  def installPrerequisites
    installDepsList depsList
  end  

  def getDefaultOptions
    opts = [
      # Use UTF-8 strings with CEGUI (string class 1)
      "-DCEGUI_STRING_CLASS=1",
      "-DCEGUI_BUILD_APPLICATION_TEMPLATES=OFF",
      "-DCEGUI_SAMPLES_ENABLED=OFF",
      "-DCEGUI_BUILD_RENDERER_OGRE=ON",
      "-DCEGUI_BUILD_RENDERER_OPENGL=OFF",
      "-DCEGUI_BUILD_RENDERER_OPENGL3=OFF",
      "-DCEGUI_BUILD_RENDERER_DIRECT3D11=OFF",
      "-DCEGUI_BUILD_RENDERER_DIRECT3D11=OFF",
    ]

    if OS.windows?
      # Use Ogre image codec
      # (we need to build at least one so let's try silly
      opts.push "-DCEGUI_BUILD_IMAGECODEC_FREEIMAGE=OFF"
      opts.push "-DCEGUI_BUILD_IMAGECODEC_SILLY=ON"
    end

    opts
  end
  
  def RequiresClone
    if OS.windows?
      return (!File.exist?(@Folder) or @CEGUIWinDeps.RequiresClone)
    else
      return !File.exist?(@Folder)
    end
  end

  def DoClone
    if !File.exist?(@Folder)
      if runSystemSafe("hg", "clone", @RepoURL) != 0
        return false
      end
    end

    if OS.windows?
      if !File.exist?(@CEGUIWinDeps.Folder)
        Dir.chdir(@Folder) do
          @CEGUIWinDeps.DoClone
        end

        onError("Failed to clone CEGUI subdependency") if !File.exist?(@CEGUIWinDeps.Folder)
      end
    end
    true
  end

  def DoUpdate
    runSystemSafe("hg", "pull")
    if runSystemSafe("hg", "update", @Version) != 0
      return false
    end

    if OS.windows?
      Dir.chdir(@CEGUIWinDeps.Folder) do
        if !@CEGUIWinDeps.DoUpdate
          return false
        end
      end
    end
    true
  end

  def DoSetup
    # Dependency build and setup so it can be found (on windows)
    if OS.windows?
      Dir.chdir(@CEGUIWinDeps.Folder) do
        @CEGUIWinDeps.Setup
        @CEGUIWinDeps.Compile
        @CEGUIWinDeps.Install
      end
      
      info "CEGUI subdependency successfully built"
    end

    FileUtils.mkdir_p "build"

    Dir.chdir("build") do
      
      return runCMakeConfigure @Options
    end
  end
  
  def DoCompile
    Dir.chdir("build") do
      return TC.runCompiler
    end
  end
  
  def DoInstall
    Dir.chdir("build") do

      if OS.windows?
        FileUtils.mkdir_p File.join(@InstallPath, "include")

        # Copy folder
        FileUtils.cp_r File.join(@Folder, "dependencies/include/glm"),
                       File.join(@InstallPath, "include")

        # Copy dependency dlls
        extraDLLs = Globber.new([
                                  "pcre.dll",
                                  "SILLY.dll",
                                  "freetype.dll",
                                  "raqm.dll",
                                  "harfbuzz.dll",
                                  "fribidi.dll",
                                  "libexpat.dll",
                                ],
                                File.join(@Folder, "cegui-dependencies/build/dependencies/"))

        FileUtils.cp extraDLLs.getResult, File.join(@InstallPath, "bin")
      end
      
      return self.cmakeUniversalInstallHelper
    end
  end

  def getInstalledFiles
    if OS.windows?
      [
        "lib/CEGUIBase-9999.lib",
        "lib/CEGUICOmmonDialogs-9999.lib",
        "lib/CEGUICoreWindowRendererSet.lib",
        "lib/CEGUIExpatParser.lib",
        "lib/CEGUIOgreRenderer-9999.lib",
        "lib/CEGUISILLYImageCodec.lib",

        "bin/CEGUIBase-9999.dll",
        "bin/CEGUICOmmonDialogs-9999.dll",
        "bin/CEGUICoreWindowRendererSet.dll",
        "bin/CEGUIExpatParser.dll",
        "bin/CEGUIOgreRenderer-9999.dll",
        "bin/CEGUISILLYImageCodec.dll",

        "bin/pcre.dll",
        "bin/SILLY.dll",
        "bin/freetype.dll",
        "bin/raqm.dll",
        "bin/harfbuzz.dll",
        "bin/fribidi.dll",
        "bin/libexpat.dll",

        "include/cegui-9999",
        "include/glm",
      ]
    else
      #onError "TODO: linux file list"
      nil
    end
  end
end


#
# Sub-dependency for Windows builds
#
class CEGUIDependencies < BaseDep
  # parent needs to be CEGUI object
  def initialize(parent, args)
    super("CEGUI Dependencies", "cegui-dependencies", args)

    if not OS.windows?
      onError "CEGUIDependencies are Windows-only, they aren't " +
              "required on other platforms"
    end

    @Folder = File.join(parent.Folder, "cegui-dependencies")

  end

  def getDefaultOptions
    [
      "-DCEGUI_BUILD_FREEIMAGE=ON"
    ]
  end

  def DoClone
    runSystemSafe("hg", "clone", "https://bitbucket.org/cegui/cegui-dependencies") == 0
  end

  def DoUpdate
    runSystemSafe("hg", "pull")
    runSystemSafe("hg", "update", "default") == 0
  end

  def DoSetup

    FileUtils.mkdir_p "build"

    Dir.chdir("build") do
      return runCMakeConfigure @Options
    end
  end
  
  def DoCompile

    Dir.chdir("build") do

      # RelWithDebInfo configuration fails because libpng.lib isn't
      # generated to the "lib/dynamic" folder in that case for some
      # reason. There's a bug report here:
      # https://bitbucket.org/cegui/cegui-dependencies/issues/7/building-silly-fails
      
      if not runVSCompiler $compileThreads, configuration: "Debug"
        return false
      end
      
      if not runVSCompiler $compileThreads, configuration: "Release"
        return false
      end
    end
    true
  end
  
  def DoInstall

    FileUtils.copy_entry File.join(@Folder, "build", "dependencies"),
                         @InstallPath
                         
    true
  end


end

