# frozen_string_literal: true

# Copyright, 2021, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'traces/context'

require 'opentelemetry'

require_relative 'open_telemetry/version'

module Traces
	module Backend
		private
		
		# Provides a backend that writes data to OpenTelemetry.
		# See <https://github.com/open-telemetry/opentelemetry-ruby> for more details.
		TRACER = ::OpenTelemetry.tracer_provider.tracer(Traces::Backend::OpenTelemetry, Traces::Backend::OpenTelemetry::VERSION)
		
		def trace(name, parent = nil, attributes: nil, &block)
			if parent
				# Convert it to the required object:
				parent = ::OpenTelemetry::Traces::SpanContext.new(
					trace_id: parent.trace_id,
					span_id: parent.span_id,
					trace_flags: ::OpenTelemetry::Traces::TracesFlags.from_byte(parent.flags),
					tracestate: parent.state,
					remote: parent.remote?
				)
			end
			
			span = TRACER.start_span(name, with_parent: parent, attributes: attributes)
			
			begin
				if block.arity.zero?
					yield
				else
					yield trace_span_context(span)
				end
			rescue Exception => error
				span&.record_exception(error)
				span&.status = ::OpenTelemetry::Traces::Status.error("Unhandled exception of type: #{error.class}")
				raise
			ensure
				span&.finish
			end
		end
		
		def trace_span_context(span)
			context = span.context
			
			return Context.new(
				context.trace_id,
				context.span_id,
				context.trace_flags,
				context.tracestate,
				remote: context.remote?
			)
		end
	end
end
