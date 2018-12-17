# Helpers for creating packaging scripts for projects
require 'sha3'

require_relative 'RubyCommon.rb'


def checkRunFolder(suggested)

  buildFolder = File.join(suggested, "build")

  onError("Not ran from base folder (no build directory exists)") if
    not File.exist?(buildFolder)

  target = File.join suggested, "build"

  target
  
end

def projectFolder(baseDir)

  File.expand_path File.join(baseDir, "../")
  
end

# def getExtraOptions(opts)

#   # opts.on("--build-docker", "If specified builds a docker file automatically otherwise " +
#   #                           "only a Dockerfile is created") do |b|
#   #   $options[:dockerbuild] = true
#   # end
  
# end

# def extraHelp
#   puts $extraParser
# end

require_relative 'RubySetupSystem.rb'

# This handles non-stripped files on linux 
def handleDebugInfoFileLinux(file)
  puts "Stripping: " + file
  if runSystemSafe("strip", file) != 0
    onError "Failed to strip: " + file
  end
end

# And this handles pdb files on windows
def handleDebugInfoFileWindows(file)
  if !File.exist? file
    return
  end
  
  puts "Deleting debug file: " + file
  FileUtils.rm file
end

def removeIfExists(file)
  if File.exists? file
    puts "Removing temporary file: " + file
    FileUtils.rm_rf file, secure: true
  end
end

# This object holds the configuration needed for making a release
class ReleaseProperties

  attr_accessor :name, :executables, :extraFiles

  def initialize(name)
    @name = name
    @executables = []
    @extraFiles = []
  end

  def addExecutable(exe)
    @executables.push exe
  end

  def addFile(file)
    @extraFiles.push file
  end
  
end

CopySource = File.join(CurrentDir, "bin")
$stripAfterInstall = true

def handlePlatform(props, platform, prettyName)

  fullName = props.name + prettyName
  
  target = File.join(CurrentDir, fullName)

  FileUtils.mkdir_p target

  binTarget = File.join(target, "bin")

  # Install first with cmake
  Dir.chdir CurrentDir do

    info "Configuring install folder: #{target}"    

    if runSystemSafe("cmake", "..", "-DCMAKE_INSTALL_PREFIX=#{target}") != 0
      onError "Failed to configure cmake install folder"
    end
    
    case platform
    when "linux"

      if runSystemSafe("make", "install") != 0
        onError "Failed to run make install"
      end

    when "windows"

      if !runVSCompiler(1, project: "INSTALL.vcxproj", configuration: "RelWithDebInfo")
        onError "Failed to run msbuild install target"
      end

    else
      onError "unknown platform"
    end
  end

  if !File.exists? binTarget
    onError "Install failed to create bin folder"
  end

  File.write(File.join(target, "package_version.txt"), fullName)

  Dir.chdir(ProjectDir){

    File.open(File.join(target, "revision.txt"), 'w') {
      |file| file.write("Package time: " + Time.now.iso8601 + "\n\n" + `git log -n 1`)
    }
  }

  # Install custom files
  props.extraFiles.each{|i|
    copyPreserveSymlinks i, target
  }
  

  # TODO: allow pausing here for manual testing
  info "Created folder: " + target
  puts "Now is an excellent time to verify that the folder is fine"
  puts "If it isn't press CTRL+C to cancel"
  waitForKeyPress
  

  # Then clean all logs and settings
  info "Cleaning logs and configuration files"
  removeIfExists File.join(binTarget, "Data/Cache")

  Dir.glob([File.join(binTarget, "*.conf"), File.join(binTarget, "*Persist.txt"),
            # These are Ogre cache files
            File.join(binTarget, "*.glsl"),
            # Log files
            File.join(binTarget, "*Log.txt"), File.join(binTarget, "*cAudioLog.html"),
            File.join(binTarget, "*LogOGRE.txt"), File.join(binTarget, "*LogCEF.txt")]
          ){|i|
    removeIfExists i
  }

  # And strip debug info 
  if $stripAfterInstall
    info "Removing debug info (TODO: generate Breakpad data if that is used)"

    case platform
    when "linux"
      Dir.glob([File.join(binTarget, "**/*.so")]){|i|
        handleDebugInfoFileLinux i
      }

      if File.exists? File.join(binTarget, "chrome-sandbox")
        handleDebugInfoFileLinux File.join(binTarget, "chrome-sandbox")
      end

      props.executables.each{|i| handleDebugInfoFileLinux File.join(binTarget, i)}
      
    when "windows"
      Dir.glob([File.join(binTarget, "**/*.pdb")]){|i|
        handleDebugInfoFileWindows i
      }

      props.executables.each{|i| handleDebugInfoFileWindows(
                               File.join(binTarget, i.sub(/.exe$/i, "") + ".pdb"))}      
    else
      onError "unknown platform"
    end
  end

  if platform == "linux"
    info "Using ldd to find required system libraries and bundling them"

    # Use ldd to find more dependencies
    lddfound = props.executables.collect{|i| lddFindLibraries File.join(binTarget, i)}.flatten

    info "Copying #{lddfound.count} libraries found by ldd on project executables"

    copyDependencyLibraries(lddfound, File.join(binTarget, "lib/"), false, true)

    # Find dependencies of dynamic Ogre libraries
    lddfound = lddFindLibraries File.join(binTarget, "lib/Plugin_ParticleFX.so")

    info "Copying #{lddfound.count} libraries found by ldd on Ogre plugins"

    copyDependencyLibraries(lddfound, File.join(binTarget, "lib/"), false, true)

    success "Copied ldd found libraries"

    info "Copied #{HandledLibraries.count} libraries to lib directory"
    
  end

  # Zip it up
  if runSystemSafe(p7zip, "a", target + ".7z", target) != 0
    onError "Failed to zip folder: " + target
  end

  puts ""
  success "Created archive: #{target}.7z"
  info "SHA3: " + SHA3::Digest::SHA256.file(target + ".7z").hexdigest
  puts ""
end


# Main run method
def runMakeRelease(props)
  info "Starting release packager. Target: #{props.name}"

  if !File.exists? CopySource
    onError "#{CopySource} folder is missing. Did you compile the project?"
  end

  if OS.linux?
    
    # Generic Linux
    handlePlatform props, "linux", "-LINUX-generic"

    # TODO: OS specific Linux package
  elsif OS.windows?

    # Windows 64 bit
    handlePlatform props, "windows", "-WINDOWS-64bit"
    
  else
    onError "unknown platform to package for"
  end

  success "Done creating packages."
end
