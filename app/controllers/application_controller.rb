class ApplicationController < ActionController::Base
  include SmartListing::Helper::ControllerExtensions
  helper SmartListing::Helper

  Forbidden = Class.new(StandardError)
  private_constant :Forbidden
  rescue_from Forbidden, with: :forbidden

  Unauthorized = Class.new(StandardError)
  private_constant :Unauthorized
  rescue_from Unauthorized, with: :unauthorized

  protect_from_forgery with: :exception
  before_action :ensure_authenticated
  after_action :ensure_access_checked

  def subject
    subject = session[:subject_id] && Subject.find_by_id(session[:subject_id])
    return nil unless subject.try(:functioning?)
    @subject = subject
  end

  protected

  def ensure_authenticated
    return force_authentication unless session[:subject_id]

    @subject = Subject.find_by_id(session[:subject_id])
    fail(Unauthorized, 'User invalid') unless @subject
    fail(Unauthorized, 'User not functional') unless @subject.functioning?
  end

  def ensure_access_checked
    return if @access_checked

    method = "#{self.class.name}##{params[:action]}"
    fail("No access control performed by #{method}")
  end

  def check_access!(action)
    fail(Forbidden) unless subject.permits?(action)
    @access_checked = true
  end

  def public_action
    @access_checked = true
  end

  def unauthorized
    reset_session
    render 'errors/unauthorized', status: :unauthorized
  end

  def forbidden
    render 'errors/forbidden', status: :forbidden
  end

  def form_error(view, message, object)
    flash.now[:error] =
        [message, error_from_validations(object)].join("\n\n")
    render(view)
  end

  def error_from_validations(object)
    object.errors.full_messages.join("\n\n")
  end

  def force_authentication
    session[:return_url] = request.url if request.get?

    redirect_to('/auth/login')
  end
end
