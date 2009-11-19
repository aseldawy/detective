module Detective

	def self.view_source(method)
		f = open("|-", "w+")
		if f == nil
			$detective_state = 0
			set_trace_func proc { |event, file, line, id, binding, classname|
				if file == '(eval)'
					$detective_state = 1
					return
				end
				return if $detective_state == 0
				if event == 'call' || event == 'c-call'
					puts("%8s %s:%-2d %10s %8s" % [event, file, line, id.inspect, classname])
					exit
				end
			}
			eval method
		else
			return f.read
		end
	end
end
