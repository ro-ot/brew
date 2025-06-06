# typed: strict
# frozen_string_literal: true

require "rubocops/extend/formula_cop"

module RuboCop
  module Cop
    module FormulaAudit
      # This cop makes sure that {Formula} is used as superclass.
      class ClassName < FormulaCop
        extend AutoCorrector

        DEPRECATED_CLASSES = %w[
          GithubGistFormula
          ScriptFileFormula
          AmazonWebServicesFormula
        ].freeze

        sig { override.params(formula_nodes: FormulaNodes).void }
        def audit_formula(formula_nodes)
          parent_class_node = formula_nodes.parent_class_node

          parent_class = class_name(parent_class_node)
          return unless DEPRECATED_CLASSES.include?(parent_class)

          problem "`#{parent_class}` is deprecated, use `Formula` instead" do |corrector|
            corrector.replace(parent_class_node.source_range, "Formula")
          end
        end
      end

      # This cop makes sure that a `test` block contains a proper test.
      class Test < FormulaCop
        extend AutoCorrector

        sig { override.params(formula_nodes: FormulaNodes).void }
        def audit_formula(formula_nodes)
          test = find_block(formula_nodes.body_node, :test)
          return unless test

          if test.body.nil?
            problem "`test do` should not be empty"
            return
          end

          problem "`test do` should contain a real test" if test.body.single_line? && test.body.source.to_s == "true"

          test_calls(test) do |node, params|
            p1, p2 = params
            if (match = string_content(p1).match(%r{(/usr/local/(s?bin))}))
              offending_node(p1)
              problem "Use `\#{#{match[2]}}` instead of `#{match[1]}` in `#{node}`" do |corrector|
                corrector.replace(p1.source_range, p1.source.sub(match[1], "\#{#{match[2]}}"))
              end
            end

            if node == :shell_output && node_equals?(p2, 0)
              offending_node(p2)
              problem "Passing 0 to `shell_output` is redundant" do |corrector|
                corrector.remove(range_with_surrounding_comma(range_with_surrounding_space(range: p2.source_range,
                                                                                           side:  :left)))
              end
            end
          end
        end

        def_node_search :test_calls, <<~EOS
          (send nil? ${:system :shell_output :pipe_output} $...)
        EOS
      end
    end

    module FormulaAuditStrict
      # This cop makes sure that a `test` block exists.
      class TestPresent < FormulaCop
        sig { override.params(formula_nodes: FormulaNodes).void }
        def audit_formula(formula_nodes)
          body_node = formula_nodes.body_node
          return if find_block(body_node, :test)
          return if find_node_method_by_name(body_node, :disable!)

          offending_node(formula_nodes.class_node) if body_node.nil?
          problem "A `test do` test block should be added"
        end
      end
    end
  end
end
