# Ogre must be installed for this to work, or the Ogre location needs to be provided
# through extra options
# Supported extra options:
# TODO: component configuration
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
    [
      # Use UTF-8 strings with CEGUI (string class 1)
      "-DCEGUI_STRING_CLASS=1",
      "-DCEGUI_BUILD_APPLICATION_TEMPLATES=OFF",
      "-DCEGUI_SAMPLES_ENABLED=OFF",
      "-DCEGUI_BUILD_RENDERER_OGRE=ON",
      "-DCEGUI_BUILD_RENDERER_OPENGL=OFF",
      "-DCEGUI_BUILD_RENDERER_OPENGL3=OFF",
    ]
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
      if runOpen3("hg", "clone", "https://bitbucket.org/cegui/cegui") != 0
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
    runOpen3("hg", "pull")
    if runOpen3("hg", "update", @Version) != 0
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
        if !@CEGUIWinDeps.Setup
          onError "CEGUI sub dependency setup failed"
        end
        if !@CEGUIWinDeps.Compile
          onError "CEGUI sub dependency setup failed"
        end
        if !@CEGUIWinDeps.Install
          onError "CEGUI sub dependency setup failed"
        end
      end
      info "CEGUI subdependency successfully built"
      onError "todo 117"
    end

    FileUtils.mkdir_p "build"

    Dir.chdir("build") do
      
      return runCMakeConfigure(@Options)
    end
  end
  
  def DoCompile
    Dir.chdir("build") do
      return runCompiler $compileThreads 
    end
  end
  
  def DoInstall
    Dir.chdir("build") do
      return self.cmakeUniversalInstallHelper
    end
  end
  
  # TODO: is this still used?
  def Enable
    ENV["CEGUI_HOME"] = File.join @InstallPath
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

  def DoClone
    runOpen3("hg", "clone", "https://bitbucket.org/cegui/cegui-dependencies") == 0
  end

  def DoUpdate
    runOpen3("hg", "pull")
    runOpen3("hg", "update", "default") == 0
  end

  def DoSetup

    FileUtils.mkdir_p "build"

    Dir.chdir("build") do
      return runCMakeConfigure @Options
    end
  end
  
  def DoCompile

    Dir.chdir("build") do

      if not runVSCompiler $compileThreads, configuration: "Debug"
        return false
      end
      
      if not runVSCompiler $compileThreads, configuration: "RelWithDebInfo"
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

