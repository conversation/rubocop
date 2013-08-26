# encoding: utf-8

module Rubocop
  module Cop
    # FIXME
    class Team
      attr_reader :errors

      def initialize(cop_classes, config, options = nil)
        @cop_classes = cop_classes
        @config = config
        @options = options || { autocorrect: false, debug: false }
        @errors = []
      end

      def autocorrect?
        @options[:autocorrect]
      end

      def debug?
        @options[:debug]
      end

      def inspect_file(file)
        begin
          processed_source = SourceParser.parse_file(file)
        rescue Encoding::UndefinedConversionError, ArgumentError => e
          handle_error(e,
                       "An error occurred while parsing #{file}.".color(:red))
          return []
        end

        offences = processed_source.diagnostics.map do |diagnostic|
          Offence.from_diagnostic(diagnostic)
        end

        # If we got any syntax errors, return only the syntax offences.
        # Parser may return nil for AST even though there are no syntax errors.
        # e.g. sources which contain only comments
        if offences.any? { |o| [:error, :fatal].include?(o.severity) }
          return offences
        end

        set_config_for_all_cops

        cops = create_cops(processed_source)
        commissioner = Commissioner.new(cops)
        offences += commissioner.investigate(processed_source)
        process_commissioner_errors(file, commissioner.errors)
        autocorrect(processed_source.buffer, cops)
        offences.sort
      end

      private

      def set_config_for_all_cops
        Cop.all.each do |cop_class|
          cop_class.config = @config.for_cop(cop_class.cop_name)
        end
      end

      def create_cops(processed_source)
        cops = []
        @cop_classes.each do |cop_class|
          cop_name = cop_class.cop_name
          next unless @config.cop_enabled?(cop_name)
          cop = setup_cop(cop_class, processed_source.disabled_lines_for_cops)
          cops << cop
        end
        cops
      end

      def setup_cop(cop_class, disabled_lines_for_cops = nil)
        cop = cop_class.new
        cop.debug = debug?
        cop.autocorrect = autocorrect?
        if disabled_lines_for_cops
          cop.disabled_lines = disabled_lines_for_cops[cop_class.cop_name]
        end
        cop
      end

      def autocorrect(buffer, cops)
        return unless autocorrect?

        corrections = cops.reduce([]) do |array, cop|
          array.concat(cop.corrections)
          array
        end

        corrector = Corrector.new(buffer, corrections)
        new_source = corrector.rewrite

        unless new_source == buffer.source
          filename = buffer.name
          File.open(filename, 'w') { |f| f.write(new_source) }
        end
      end

      def process_commissioner_errors(file, file_errors)
        file_errors.each do |cop, errors|
          errors.each do |e|
            handle_error(e,
                         "An error occurred while #{cop.name}".color(:red) +
                         " cop was inspecting #{file}.".color(:red))
          end
        end
      end

      def handle_error(e, message)
        @errors << message
        warn message
        if debug?
          puts e.message, e.backtrace
        else
          warn 'To see the complete backtrace run rubocop -d.'
        end
      end
    end
  end
end
