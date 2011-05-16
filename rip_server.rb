require "rubygems"
require 'mq'
require 'json'
require 'RMagick'
require 'builder'

Signal.trap('INT') {
  AMQP.stop{ EM.stop }
   Process.exit!(true)
 }
Signal.trap('TERM'){
  AMQP.stop{ EM.stop }
   Process.exit!(true)
 }

puts "Welcome"
puts "Starting RIP-server..."

def generate_output(name, status_to_xml)
  puts "  [-]generating xml data"
  xml_output = Builder::XmlMarkup.new
  xml_output.report do
    xml_output.units ""
    xml_output.height "0.0"
    xml_output.width "0.0"
    xml_output.colorspace ""
    xml_output.colorcomponents "0"
    xml_output.pagecount "0"
    xml_output.origFilepath ""
    xml_output.placement ""
    xml_output.thumbnailPath ""
    xml_output.origCreatingApp ""
    xml_output.datecreated "04-21-2011"
    xml_output.dateprocessed "24:09 04-21-2011"
    xml_output.processingstatus ""
    xml_output.errorcode "-1"
    xml_output.errormessage "#{status_to_xml[:error_message]}"
  end
  puts "    ...done"
  path_to_fo = "/home/sfate/prj/last_odt/tmp/fo/"
  Dir::mkdir(path_to_fo) if !File.directory? path_to_fo
  xml_path = path_to_fo + name + '.xml'

  puts "  [-]saving file"
  xml_data = xml_output.target!
  puts "      path: #{xml_path}"
  file = File.new(xml_path, "w+")
    file.write(xml_data)
  file.close
  puts "    ...done"

  return_values = {
    :xml_path => xml_path,
    :respond_status => status_to_xml[:condition]
  }
  return return_values
  #puts "#{return_values.inspect}"
end

def parse_new_file(recieved_message, request)
    puts "======-Received data from broker-======"
    puts "[*]recieved_message:"
    puts "  #{recieved_message.inspect}"
    name_of_pdf = File.basename(recieved_message["src"],'.pdf')
    puts "[*]name_of_pdf:"
    puts "  #{name_of_pdf}"
    status_to_xml = {
      :condition => "ok",
      :error_message => ""
    }
    array_of_images = []
    array_of_sizes = []
    path = ""
    take_report = Hash.new
    array_of_full_images_info = []
    begin
      path = "#{File.dirname(recieved_message["src"])}/#{File.basename(recieved_message["src"], '.pdf')}"
      Dir::mkdir(path) if !File.directory? path
      puts "[*]parsing..."
      sleep 0.2
      puts "[*]raster images..."
        #parse pdf file via ImageMagick
        #images_list = Magick::ImageList.new(recieved_message["src"])
        puts "  Could take a while..."
      make_pngs = "convert #{recieved_message['src']} #{path}/#{name_of_pdf}_Page%03d.png" #-density 300
      system make_pngs
      Dir.foreach(path) do |image|
         array_of_full_images_info.push(Magick::Image.ping("#{path}/#{image}")) if (image.match(/Page/))
      end
      images_list =
      puts "  ...done"

    #  puts "[*]vector images..."
      #parse pdf file via PDFtk
        #make_pdfs = "pdftk #{recieved_message['src']} burst output #{path}/#{name_of_pdf}_Page%03d.pdf"
        #system make_pdfs
     #   puts "    no need of that...\n  [-]exiting parsing to pdfs..."
      #puts "  ...done"
	puts "array_of_full_images_info: #{array_of_full_images_info}"
      array_of_full_images_info.each do |img|
        image = img[0]
        image_name = File.basename(image.filename)
        array_of_images.push(image_name)
        array_of_sizes.push("#{image.columns}x#{image.rows}")
      end
    rescue => ex
      puts "  ...Fail\n====-Error output-===="
      puts "Class:  #{ex.class.to_s}\nReason: #{ex.message}"
      puts "====-End of output-===="
      status_to_xml[:condition] = "error"
      status_to_xml[:error_message] = "#{ex.class.to_s}: #{ex.message}"
    end

    puts "[*]generating xml_report..."
    take_report = generate_output(name_of_pdf, status_to_xml)
    puts "take_report: #{take_report.inspect}"
    puts "  ...done"
    xml_path = take_report[:xml_path]
    status = take_report[:respond_status]
    data_to_send = {
  	  :folder_url => path,
	    :images_array => array_of_images,
	    :sizes_array => array_of_sizes,
	    :status => status,
	    :xml_respond => xml_path
    }.to_json
    puts "======-End of the report-======"
    sleep 2
    #send message to broker
    puts"..."
    puts "Sending data..."
    puts "#{data_to_send.inspect}"
    request.publish(data_to_send)
    puts "...done\nWaiting for next queue..."
end


AMQP.start(:host => 'localhost', :port => '5672') do
  recieved_message = ""
  MQ.queue('rip_send').subscribe(:ack => true) do |h,m|
       puts m
       unless m.nil?
         recieved_message = JSON.parse(m)
         h.ack
         #puts recieved_message.inspect
         parse_new_file(recieved_message, MQ.queue('rip_respond'))
       end
  end
end

