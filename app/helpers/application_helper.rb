module ApplicationHelper
  include ActiveSupport::Inflector

  PORTABILIS_LOGO = 'portabilis_logo.png'.freeze
  PROFILE_DEFAULT_PICTURE_PATH = '/assets/profile-default.jpg'.freeze

  def unread_notifications_count
    @unread_notifications_count ||= current_user.unread_notifications.count
  end

  def last_system_notifications
    @last_system_notifications ||= current_user.system_notifications.limit(10).ordered
  end

  def system_notification_path(notification)
    SystemNotificationRouter.path(notification)
  end

  def unities
    @unities ||= Unity.ordered
  end

  def resource
    instance_variable_get("@#{controller_name.singularize}")
  end

  def tagfy(value)
    transliterate(value).tr(' ', '_').underscore
  end

  def breadcrumbs
    Navigation.draw_breadcrumbs(controller_name, self)
  end

  def menus
    key = [
      'Menus',
      controller_name,
      current_user.current_user_role&.role&.cache_key || current_user.cache_key,
      Translation.cache_key
    ]

    Rails.cache.fetch(key, expires_in: 1.day) do
      Navigation.draw_menus(controller_name, current_user)
    end
  end

  def shortcuts
    key = [
      'HomeShortcuts',
      current_user.current_user_role&.role&.cache_key || current_user&.cache_key,
      Translation.cache_key
    ]

    Rails.cache.fetch(key, expires_in: 1.day) do
      Navigation.draw_shortcuts(current_user)
    end
  end

  def title
    Navigation.draw_title(controller_name, false, self)
  end

  def title_with_icon
    Navigation.draw_title(controller_name, true, self)
  end

  def simple_form_for(object, *args, &block)
    options = args.extract_options!
    options[:builder] ||= Portabilis::FormBuilder

    super object, *(args << options), &block
  end

  def profile_picture_tag(user, profile_picture_html_options = {})
    user_avatar_url = user_avatar_url(user)

    return unless user_avatar_url

    image_tag(user_avatar_url, profile_picture_html_options.merge(onerror: on_error_img, alt: ''))
  end

  def user_avatar_url(user)
    user_avatar = user.profile_picture&.url
    student_avatar = user.student&.avatar_url.to_s
    cache_key = [:user_avatar_url, current_entity.id, user.id, user_avatar, student_avatar]
    Rails.cache.fetch cache_key, expires_in: 1.day do
      user_avatar ||
        IeducarAvatarAuth.new(student_avatar).generate_new_url.presence ||
        PROFILE_DEFAULT_PICTURE_PATH
    end
  end

  def on_error_img
    "this.error=null;this.src='#{PROFILE_DEFAULT_PICTURE_PATH}'"
  end

  def custom_date_format(date)
    if date == Time.zone.today
      t('date.today')
    elsif date == Time.zone.yesterday
      t('date.yesterday')
    elsif date.year == Time.zone.today.year
      l(date, format: :short)
    else
      l(date, format: :long)
    end
  end

  def filename(file)
    file.path.split('/').last
  end

  def t_boolean(value)
    value ? t('boolean.yes') : t('boolean.no')
  end

  def number_of_classes_elements(number_of_classes)
    elements = []
    (1..number_of_classes).each do |i|
      elements << { id: i, name: i, text: i }
    end
    elements.to_json
  end

  def decimal_input_mask(number_of_decimal_places)
    if number_of_decimal_places
      { data: { inputmask: "'digits': #{number_of_decimal_places}" } }
    else
      { data: { inputmask: "'digits': 0" } }
    end
  end

  def entity_copyright
    Rails.cache.fetch("#{Entity.current.try(:id)}_entity_copyright", expires_in: 1.day) do
      "© #{GeneralConfiguration.current.copyright_name} #{Time.zone.today.year}"
    end
  end

  def entity_website
    Rails.cache.fetch("#{Entity.current.try(:id)}_entity_website", expires_in: 1.day) do
      GeneralConfiguration.current.support_url
    end
  end

  def alert_by_entity(_entity_name)
    ''
  end

  def initial_value_for_select2_remote(id, description)
    '{"id": ' + id.to_s + ', "description": "' + description.tr("\n", ' ') + '"}'
  end

  def link_to_if_and_else(*args, &block)
    condition = args.shift
    content = capture(&block)

    if condition
      link_to(*args) do
        content
      end
    else
      content
    end
  end

  def present(model)
    klass = "#{model.class}Presenter".constantize
    presenter = klass.new(model, self)

    yield(presenter) if block_given?
  end

  def back_link(name, path)
    content_for :back_link do
      back_link_tag(name, path)
    end
  end

  def back_link_tag(name, path)
    link_to path, class: 'back-link' do
      raw <<-HTML
        <i class="icon-append fa fa-angle-left"></i>
        #{name}
      HTML
    end
  end

  def include_recaptcha_js
    return '' if recaptcha_site_key.blank?

    raw %Q{
      <script src="https://www.google.com/recaptcha/api.js?render=#{recaptcha_site_key}"></script>
    }
  end

  def recaptcha_execute
    return '' if recaptcha_site_key.blank?

    id = "recaptcha_token_#{SecureRandom.hex(10)}"

    raw %Q{
      <input name="recaptcha_token" type="hidden" id="#{id}"/>
      <script>
        grecaptcha.ready(function() {
          grecaptcha.execute('#{recaptcha_site_key}').then(function(token) {
            document.getElementById("#{id}").value = token;
          });
        });
      </script>
    }
  end

  def window_state
    current_profile = CurrentProfile.new(current_user)

    {
      current_role: current_profile.user_role_as_json,
      available_roles: current_profile.user_roles_as_json,
      current_unity: current_profile.unity_as_json,
      available_unities: current_profile.unities_as_json,
      current_school_year: current_profile.school_year_as_json,
      available_school_years: current_profile.school_years_as_json,
      current_classroom: current_profile.classroom_as_json,
      available_classrooms: current_profile.classrooms_as_json,
      current_teacher: current_profile.teacher_as_json,
      available_teachers: current_profile.teachers_as_json,
      current_discipline: current_profile.discipline_as_json,
      available_disciplines: current_profile.disciplines_as_json,
      teacher_id: current_user.teacher_id,
      current_profile: current_profile.teacher_profile_as_json,
      profiles: current_profile.teacher_profiles_as_json

    }
  end

  private

  def cache_key_to_user
    [current_entity.id, current_user.id]
  end

  def recaptcha_site_key
    @recaptcha_site_key ||= Rails.application.secrets.recaptcha_site_key
  end

  def logo_url
    Rails.cache.fetch([current_entity.id, current_entity_configuration]) do
      entity_logo_url = current_entity_configuration.try(:logo_url)

      return PORTABILIS_LOGO if entity_logo_url.blank?
      return entity_logo_url if RestClient.get(entity_logo_url).code == 200

      PORTABILIS_LOGO
    end
  rescue Errno::ECONNREFUSED, SocketError
    PORTABILIS_LOGO
  rescue => error
    Honeybadger.notify(error)

    PORTABILIS_LOGO
  end
end
