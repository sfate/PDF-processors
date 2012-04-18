module ProcessPDF
  class Create

    def initialize(options={})
      @fo_file = options[:file]
    end

    def process
      fop_dir  = File.join(File.dirname(__FILE__), '..', '/vendor/fop-1.0')
      fo_name  = File.basename(@fo_file, '.fo')
      fo_path  = File.dirname(@fo_file)
      pdf_path = "#{fo_path}/#{fo_name}.pdf"
      Dir::mkdir(fo_path) if !File.directory? path
      # We generate the classpath by scanning the FOP lib directory
      command = "java -cp #{locale_fop_path}/build/fop.jar"
      Dir.foreach("#{locale_fop_path}/lib") do |file|
        command << ":#{locale_fop_path }/lib/#{file}" if (file.match(/.jar/))
      end
      command << " org.apache.fop.cli.Main "
      command << " -fo #{@fo_file}"
      #    command << " -xsl #{locale_fop_path}/xslt/doc2fo.xsl"
      command << " -pdf #{pdf_path}"
      unless system command
        raise StandardError "Can't create PDF file, case:\n"+`#{command}`
      end
    end

  end
end

