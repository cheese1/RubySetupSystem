# Supported extra options:
#
class AngelScript < ZipAndCmakeDLDep
  def initialize(args)
    super('AngelScript', 'angelscript', args, zipType: :p7zip)

    self.HandleStandardCMakeOptions

    # Revision
    @Version ||= 2547

    # Only hashes change with different versions
    case @Version
    when 2482
      @DLHash = '2138306e4a9ec36070b2be9adcb64d39b76aad392a36d1d15bb05a92f516f211'
    when 2547
      @DLHash = '7d1ace2eeabd1554684bfa514e8cbb79656a8bf9b8397de46328b80b21693409'
    else
      onError "unknown AngelScript version (RubySetupSystem doesn't know about: " +
              @Version + ')'
    end

    # sha3
    @DLHashType = 2
    @DownloadURL = "https://boostslair.com/rubysetupsystem/deps/angelscript_#{@Version}.7z"
    @CMakeListFolder = '../sdk/angelscript/projects/cmake/'
    @LocalFileName = "angelscript_#{@Version}.7z"
    @UnZippedName = 'angelscript'
    @LocalPath = File.join(CurrentDir, @LocalFileName)

    # For packaging
    @RepoURL = @DownloadURL
  end

  def DoInstall
    # Copy files to the install target folder
    installer = CustomInstaller.new(@InstallPath,
                                    File.join(@Folder, 'sdk/angelscript/include'))

    # First header files and libs
    installer.addInclude(File.join(@Folder, 'sdk/angelscript/include', 'angelscript.h'))

    # The library
    if OS.linux?

      installer.addLibrary File.join(@Folder, 'build/', 'libangelscript.a')

    elsif OS.windows?
      # TODO: bitness
      installer.addLibrary File.join(@Folder, "build/#{CMakeBuildType}", 'angelscript.lib')
    else
      onError 'Unkown OS'
    end

    installer.run

    # Then the addons
    installer = CustomInstaller.new(@InstallPath,
                                    File.join(@Folder, 'sdk/add_on/'))

    installer.IncludeFolder = 'include/add_on'

    # All the addons from
    # `ls -m | awk 'BEGIN { RS = ","; ORS = ", "}; NF { print "\""$1"\""};'`
    addonnames = Array[
      'autowrapper', 'contextmgr', 'datetime', 'debugger', 'scriptany', 'scriptarray',
      'scriptbuilder', 'scriptdictionary', 'scriptfile', 'scriptgrid', 'scripthandle',
      'scripthelper', 'scriptmath', 'scriptstdstring', 'serializer', 'weakref'
    ]

    addonnames.each do |x|
      installer.addInclude File.join(@Folder, 'sdk/add_on/', x)
    end

    installer.run

    true
  end

  def getInstalledFiles
    if OS.windows?
      [
        'lib/angelscript.lib',
        'include/angelscript.h',
        'include/add_on'
      ]
    elsif OS.linux?
      [
        'lib/libangelscript.a',
        'include/angelscript.h',
        'include/add_on'
      ]
    end
  end
end
