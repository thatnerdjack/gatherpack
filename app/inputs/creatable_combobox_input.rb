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

  private

  # simple_form only links an association's errors to a field when the input was
  # built by `f.association`; this one takes the foreign key directly. Without
  # this, `belongs_to`'s "must exist" lands on :team_type and the :team_type_id
  # field is never flagged, so submitting with no team type chosen fails
  # silently as far as the form is concerned.
  def association_reflection
    return @association_reflection if defined?(@association_reflection)

    name = attribute_name.to_s.delete_suffix("_id")
    @association_reflection =
      if name == attribute_name.to_s then nil
      else object.class.try(:reflect_on_association, name.to_sym)
      end
  end

  def errors_on_association
    association_reflection ? object.errors[association_reflection.name] : []
  end

  def full_errors_on_association
    association_reflection ? object.errors.full_messages_for(association_reflection.name) : []
  end
end
