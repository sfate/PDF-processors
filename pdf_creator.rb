require "rubygems"
require 'mq'
require 'json'

Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

puts "Welcome"
puts "Starting PDF-creator..."

def create_new_file(recieved_message, request)
  current_dir = File.join(Dir.pwd, '..', '/vendor/fop-1.0')
  name_of_fo = File.basename(recieved_message["src"], '.fo')
  fo_receive= name_of_fo
  sleep 2
  status_to_xml = {
    :condition => "ok",
    :error_message => ""
  }
  path = "#{File.dirname(recieved_message["src"])}"
  complete_pdf_path = "#{path}#{name_of_fo}.pdf"
  Dir::mkdir(path) if !File.directory? path

  # We generate the classpath by scanning the FOP lib directory
  command = "java -cp #{locale_fop_path}/build/fop.jar"
  Dir.foreach("#{locale_fop_path}/lib") do |file|
      command << ":#{locale_fop_path }/lib/#{file}" if (file.match(/.jar/))
  end
  command << " org.apache.fop.cli.Main "
  command << " -fo #{recieved_message['src']}"
 #    command << " -xsl #{locale_fop_path}/xslt/doc2fo.xsl"
  command << " -pdf #{complete_pdf_path}"
  if(system command) then
    puts "Done. Exiting..."
  else
    status_to_xml.update({
      :condition     => "error",
      :error_message => `#{command}`
    }
    puts "Fail. Look at error message in queue for details"
  end

  data_to_send = {
    :pdf_url => "#{complete_pdf_path}",
    :error => status_to_xml
  }.to_json

  request.publish(data_to_send)
end

recieved_message = ""
AMQP.start(:host => 'localhost', :port => '5672') do

  if_mesage_is_not_nil = false
  MQ.queue('create_send').subscribe(:ack => true) do |h,m|
      puts m
      unless m.nil?
        recieved_message = JSON.parse(m)
        h.ack
        puts recieved_message.inspect
        if_mesage_is_not_nil = true
      end
      if if_mesage_is_not_nil
        puts "check nil message or not"
        if_mesage_is_not_nil = false
        create_new_file(recieved_message, MQ.queue('create_respond'))
      end
  end
  recieved_message
end

