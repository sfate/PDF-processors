module ProcessPDF
  class Rip

    def initialize(options={})
      @pdf_file = options["file"]
    end

    def parse
      pdf_name = File.basename(@pdf_file,'.pdf')
      out_path = File.join(File.dirname(@pdf_file), pdf_name)
      object_images_array = images_array = []
      Dir::mkdir(out_path) unless File.directory?(out_path)
      #parse pdf file via ImageMagick
      make_pngs = "convert #{@pdf_file} #{path}/#{pdf_name}_Page%03d.png" #-density 300
      unless system make_pngs
        raise StandardError, "Can't parse pdf, case:\n#{`makepngs`}"
      end
      Dir.foreach(out_path) do |image|
        object_images_array.push(Magick::Image.ping("#{out_path}/#{image}")) if (image.match(/Page/))
      end
      object_images_array.each do |img|
        image      = img[0]
        image_name = File.basename(image.filename)
        images_array.push({:name => image_name, :size => {:width => image.columns, :height => image.rows}})
        images_array.push(image_name)
      end
      {:images => images_array, :folder => out_path}
    end

  end
end

