module YARD
  module Generators
    class TagsGenerator < Base
      before_section :header,  :has_tags?
      before_section :option, :has_options?
      before_section :param, :has_params?
      before_section :overload, :has_overloads?
      
      def sections_for(object)
        [:header, [
            :example, :param, :yieldparam,
            :yieldreturn, :return, :raise,
            :overload, [G(DocstringGenerator), self],
            :author, :version, :since, :see
          ]
        ]
      end
      
      def yieldparam(object)
        render_tags :yieldparam
      end

      def yieldreturn(object)
        render_tags :yieldreturn
      end

      def return(object)
        render_tags :return
      end
      
      def raise(object)
        render_tags :raise, :no_names => true
      end
      
      def author(object)
        render_tags :author, :no_types => true, :no_names => true
      end

      def version(object)
        render_tags :version, :no_types => true, :no_names => true
      end

      def since(object)
        render_tags :since, :no_types => true, :no_names => true
      end
      
      protected
      
      def has_params?(object)
        tags_by_param(object).size > 0
      end
      
      def has_tags?(object)
        object.tags.size > 0
      end
      
      def has_options?(object)
        object.has_tag?(:option)
      end
      
      def has_overloads?(object)
        object.has_tag?(:overload)
      end
      
      def render_tags(name, opts = {})
        opts = { :name => name }.update(opts)
        render(current_object, 'tags', opts)
      end
      
      def tags_by_param(object)
        cache = {}
        [:param, :option].each do |sym|
          object.tags(sym).each do |t|
            cache[t.name.to_s] = t
          end
        end
        
        object.parameters.map do |p|
          name = p.first.to_s
          cache[name] || cache[name[/^[*&](\w+)$/, 1]]
        end.compact
      end
    end
  end
end