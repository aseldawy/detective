require 'ruby_parser'

module Detective

  begin
    fork {exit!}
    ForkSupported = true
  rescue Exception
    ForkSupported = false
  end

	def self.view_source(method, format=:plain)
    location = get_location(method).strip.split /[\r\n]+/
    case location.first
      when 'native method' then return 'native method'
      when 'error' then raise location[1..-1].join(' ')
      when 'location' then
      begin
        filename, line_no = location[1,2] 
        line_no = line_no.to_i
        f = File.open filename
        source = ""
        output = case format
          when :plain then ""
          when :rdoc then "#{filename}, line #{line_no}" << "\r\n"
          else ""
        end
        current_line_no = 0
        rp = RubyParser.new
        f.each_line do |current_line|
          current_line_no += 1
          if current_line_no >= line_no
            output << case format
              when :plain then current_line
              when :rdoc then "#{current_line_no}:#{current_line}"
              else current_line
            end
            source << current_line
            # Try to parse it to know whether the method is complete or not
            rp.parse(source) && break rescue nil
          end
        end
        f.close
        return output
      rescue Exception => e
        return "Cannot find source code"
      end
    end
	end
	
	# Finds the location of a method in ruby source files
	# You can pass a string like
	# * 'Class.name' class method
	# # 'String#size' instance method
	def self.get_location(ruby_statement)
    if ruby_statement.index('#')
      # instance method
      class_name, method_name = ruby_statement.split('#')
      class_method = false
    elsif ruby_statement.index('.')
      class_name, method_name = ruby_statement.split('.')
      class_method = true
    else
      raise "Invalid parameter"
    end
    the_klass = eval(class_name)
    ForkSupported ? get_location_fork(the_klass, method_name, class_method) : get_location_thread(the_klass, method_name, class_method)
  end
  
private

  def self.get_location_thread(the_klass, method_name, class_method)
    result = ""
    t = Thread.new do
      begin
        # child process
        detective_state = 0
        # Get an instance of class Method that can be invoked using Method#call
        the_method, args = get_method(the_klass, method_name, class_method)
        set_trace_func(proc do |event, file, line, id, binding, classname|
          if id == :call
            detective_state = 1
            return
          end
          return if detective_state == 0
          if event == 'call'
            result << "location" << "\r\n"
            result << file << "\r\n"
            result << line.to_s << "\r\n"
            # Cancel debugging
            set_trace_func nil
            Thread.kill(Thread.current)
          elsif event == 'c-call'
            result << 'native method'
            set_trace_func nil
            Thread.kill(Thread.current)
          end
        end)

        the_method.call *args
        # If the next line executed, this indicates an error because the method should be cancelled before called
        result << "method called!" << "\r\n"
      rescue Exception => e
        result << "error" << "\r\n"
        result << e.inspect << "\r\n"
      end
    end
    t.join
    result
  end

  def self.get_location_fork(the_klass, method_name, class_method)
    f = open("|-", "w+")
    if f == nil
      begin
        # child process
        detective_state = 0
        # Get an instance of class Method that can be invoked using Method#call
        the_method, args = get_method(the_klass, method_name, class_method)
        set_trace_func(proc do |event, file, line, id, binding, classname|
          if id == :call
            detective_state = 1
            return
          end
          return if detective_state == 0
          if event == 'call'
            puts "location"
            puts file
            puts line
            set_trace_func nil
            exit!
          elsif event == 'c-call'
            puts 'native method'
            set_trace_func nil
            exit!
          end
        end)
      
        the_method.call *args
        # If the next line executed, this indicates an error because the method should be cancelled before called
        puts "method called!"
      rescue NoMethodError => e
        puts "No method found #{method_name}"
        puts e.inspect
        puts e.backtrace.join("\n")
      rescue Exception => e
        puts "error"
        puts e.inspect
        puts e.backtrace.join("\n")
      ensure
        exit!
      end
    else
      Process.wait
      x = f.read
#      puts x
      return x
    end
  end
  
  def self.get_method(the_klass, method_name, class_method)
    if class_method
      the_method = the_klass.method(method_name)
    elsif the_klass.is_a? Class
      # Create an instance of the given class
      # Create a new empty initialize method to bypass initialization ...
      # because some classes require special attributes when created.
      # Some other like ActiveRecord::Base does not allow to be instantiated at all
      the_klass.class_eval do
        alias old_initialize initialize
        def initialize
          # Bypass initialization
        end
      end
      the_method = the_klass.new.method(method_name)
      # Revert initialize method
      the_klass.class_eval do
        # undef causes a warning with :initialize
#        undef initialize
        alias initialize old_initialize
      end
    elsif the_klass.is_a? Module
      # Crate any object and let it extends the given module
      object = Object.new
      object.extend the_klass
      the_method = object.method(method_name)
    end
    # check how many attributes are required
    the_method_arity = the_method.arity
    required_args = the_method_arity < 0 ? -the_method_arity-1 : the_method_arity
    
    # Return the method and its parameters
    [the_method, Array.new(required_args)]
  rescue NameError => e
    if method_name != 'method_missing' &&
      (
       class_method && the_klass.respond_to?(:method_missing) ||
       !class_method && the_klass.instance_methods.include?('method_missing')
      )
      method_name = 'method_missing'
      retry
    else
      raise
    end
  end

end
