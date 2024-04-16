# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # Detects the use of the `public_send` method with a literal method name argument.
      # Since the `send` method can be used to call private methods, by default,
      # only the `public_send` method is detected.
      #
      # @safety
      #   This cop is not safe because it can incorrectly detect based on the receiver.
      #   Additionally, when `AllowSend` is set to `true`, it cannot determine whether
      #   the `send` method being detected is calling a private method.
      #
      # @example
      #   # bad
      #   obj.public_send(:method_name)
      #   obj.public_send('method_name')
      #
      #   # good
      #   obj.method_name
      #
      # @example AllowSend: true (default)
      #   # good
      #   obj.send(:method_name)
      #   obj.send('method_name')
      #   obj.__send__(:method_name)
      #   obj.__send__('method_name')
      #
      # @example AllowSend: false
      #   # bad
      #   obj.send(:method_name)
      #   obj.send('method_name')
      #   obj.__send__(:method_name)
      #   obj.__send__('method_name')
      #
      #   # good
      #   obj.method_name
      #
      class SendWithLiteralMethodName < Base
        extend AutoCorrector

        MSG = 'Use `%<method_name>s` method call directly instead.'
        RESTRICT_ON_SEND = %i[public_send send __send__].freeze
        STATIC_METHOD_NAME_NODE_TYPES = %i[sym str].freeze

        # rubocop:disable Metrics/AbcSize
        def on_send(node)
          return if allow_send? && !node.method?(:public_send)
          return unless (first_argument = node.first_argument)
          return unless STATIC_METHOD_NAME_NODE_TYPES.include?(first_argument.type)

          offense_range = offense_range(node)
          method_name = first_argument.value

          add_offense(offense_range, message: format(MSG, method_name: method_name)) do |corrector|
            if node.arguments.one?
              corrector.replace(offense_range, method_name)
            else
              corrector.replace(node.loc.selector, method_name)
              corrector.remove(removal_argument_range(first_argument, node.arguments[1]))
            end
          end
        end
        # rubocop:enable Metrics/AbcSize

        private

        def allow_send?
          !!cop_config['AllowSend']
        end

        def offense_range(node)
          node.loc.selector.join(node.source_range.end)
        end

        def removal_argument_range(first_argument, second_argument)
          first_argument.source_range.begin.join(second_argument.source_range.begin)
        end
      end
    end
  end
end
