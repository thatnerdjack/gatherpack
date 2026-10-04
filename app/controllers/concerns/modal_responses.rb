# Shared plumbing for resources whose new/show/edit screens render into a
# `shared/remote_modal` turbo frame instead of onto pages of their own.
#
# The pattern is deliberately additive: the regular full-page templates still
# render for ordinary navigation, so a resource opts in by rendering its modal
# partial when the request came from the frame, and by answering modal
# submissions with turbo streams instead of a redirect.
module ModalResponses
  extend ActiveSupport::Concern

  private

  # True when this request is a turbo frame navigation aimed at the named
  # modal, i.e. the user opened the modal rather than the full page.
  def modal_frame_request?(frame_id)
    turbo_frame_request_id == frame_id
  end

  # True when a form rendered inside the modal submitted this request, so the
  # response should update the current page in place rather than redirect.
  def modal_submission?
    params[:modal].present?
  end

  # A flash message, as a turbo stream aimed at the layout's flash container.
  def modal_flash(type, message)
    turbo_stream.prepend("flash-messages", partial: "layouts/flash", locals: { type: type, message: message })
  end
end
