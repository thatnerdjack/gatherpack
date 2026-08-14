# frozen_string_literal: true

# A combobox over an existing collection that can also name a record which
# doesn't exist yet. Typing a name that matches nothing submits it under
# :name_when_new instead of the association's foreign key, and the model turns
# it into a record. Omit :name_when_new to restrict the field to the collection.
class CreatableComboboxInput < SimpleForm::Inputs::Base
  def input(wrapper_options = nil)
    raise ArgumentError, "CreatableComboboxInput requires a :collection option" if @options[:collection].nil?

    html_options = merge_wrapper_options(input_html_options.dup, wrapper_options || {})
    # Keep the combobox's own id in step with the label simple_form renders.
    html_options[:id] ||= "#{object_name}_#{attribute_name}"

    @builder.combobox attribute_name, @options[:collection],
      name_when_new: @options[:name_when_new],
      # simple_form draws the field's label, so the combobox only needs one for
      # the full-screen dialog it opens on narrow viewports.
      dialog_label: @options.fetch(:dialog_label) { raw_label_text },
      **html_options
  end
end
