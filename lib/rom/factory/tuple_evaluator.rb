module ROM
  module Factory
    class TupleEvaluator
      attr_reader :attributes

      attr_reader :relation

      attr_reader :model

      attr_reader :sequence

      def initialize(attributes, relation)
        @attributes = attributes
        @relation = relation.with(auto_struct: true)
        @model = @relation.combine(*assoc_names).mapper.model
        @sequence = 0
      end

      def defaults(attrs)
        evaluate(attrs).merge(attrs)
      end

      def struct(attrs)
        model.new(struct_attrs.merge(defaults(attrs)))
      end

      def persist_associations(tuple, parent)
        assoc_names.each do |name|
          assoc = tuple[name]
          assoc.(parent) if assoc.is_a?(Proc)
        end
      end

      def assoc_names
        attributes.associations.map(&:name)
      end

      def has_associations?
        assoc_names.size > 0
      end

      def primary_key
        relation.primary_key
      end

      private

      def evaluate(attrs)
        evaluate_values(attrs).merge(evaluate_associations(attrs))
      end

      def evaluate_values(attrs)
        attributes.values.tsort.each_with_object({}) do |attr, h|
          deps = attr.dependency_names.map { |k| h[k] }.compact
          result = attr.(attrs, *deps)

          if result
            h.update(result)
          end
        end
      end

      def evaluate_associations(attrs)
        attributes.associations.each_with_object({}) do |assoc, h|
          if assoc.dependency?(relation)
            h[assoc.name] = -> parent { assoc.call(parent) }
          else
            h.update(assoc.(attrs))
          end
        end
      end

      def struct_attrs
        relation.schema.
          reject(&:primary_key?).
          map { |attr| [attr.name, nil] }.
          to_h.
          merge(primary_key => next_id)
      end

      def next_id
        @sequence += 1
      end
    end
  end
end