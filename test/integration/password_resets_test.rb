require 'test_helper'

class PasswordResetsTest < ActionDispatch::IntegrationTest
  
  def setup
    ActionMailer::Base.deliveries.clear
    @user = users(:michael)
  end

  test "password resets" do
    get new_password_reset_path
    assert_template 'password_resets/new'
    assert_select   'input[name=?]', 'password_reset[email]'

    # MailAddress is not valid
    post password_resets_path, params: { password_reset: { email: ""}}
    assert_not flash.empty?
    assert_template 'password_resets/new'

    # MailAdress is valid
    post password_resets_path, params: { password_reset: { email: @user.email}}
    assert_not_equal @user.reset_digest, @user.reload.reset_digest
    assert_equal     1, ActionMailer::Base.deliveries.size
    assert_not flash.empty?
    assert_redirected_to root_url

    # password reset-form's test"
    user = assigns(:user)

     # MailAdress is not valid
    get edit_password_reset_path(user.reset_token, email: "")
    assert_redirected_to root_url

     # User is not valid
    user.toggle!(:activated)
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_redirected_to root_url
    user.toggle!(:activated)

    # MailAdress is valid, token is not valid
    get edit_password_reset_path('wrong token', email: user.email)
    assert_redirected_to root_url
    
    # MailAdress and token are valid
    get edit_password_reset_path(user.reset_token, email: user.email)
    assert_template 'password_resets/edit'
    assert_select "input[name=email][type=hidden][value=?]", user.email
    
    # invalid password and password_confirmation
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: {password: "foobaz", password_confirmation: "barquux"}}
    assert_select 'div#error_explanation'

    # password is blank
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: {password: "foobaz", password_confirmation: "barquux"}}

    # password and password_confirmation are valid
    patch password_reset_path(user.reset_token),
          params: { email: user.email,
                    user: {password: "foobaz", password_confirmation: "foobaz"}}
    assert is_logged_in?
    assert_not flash.empty?
    assert_redirected_to user
    assert_nil user.reload.reset_digest
  end

  test "expired token" do
      get new_password_reset_path
      post password_resets_path,
           params: { password_reset: { email: @user.email}}
      @user = assigns(:user)
      @user.update_attribute(:reset_sent_at, 3.hours.ago)
      patch password_reset_path(@user.reset_token),
            params: { email: @user.email,
                      user: { password: "foobar", password_confirmation: "foobar"}}
      assert_response :redirect
      follow_redirect!
      assert_match "expired", response.body
  end  
end
