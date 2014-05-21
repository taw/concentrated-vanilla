class File
  def self.first_matching(file_name, *directories)
    directories.map{|dir| "#{dir}/#{file_name}"}.find{|file_path| File.exist?(file_path)} or
    raise "Cannot find #{file_name} in any of: #{directories.join(' ')}"
  end
end
