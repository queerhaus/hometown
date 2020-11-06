import { connect } from 'react-redux';
import React from 'react';
import PropTypes from 'prop-types';
import { FormattedMessage, defineMessages, injectIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { invitesEnabled, version, repository, source_url } from 'mastodon/initial_state';
import { logOut } from 'mastodon/utils/log_out';
import { openModal } from 'mastodon/actions/modal';

const messages = defineMessages({
  logoutMessage: { id: 'confirmations.logout.message', defaultMessage: 'Are you sure you want to log out?' },
  logoutConfirm: { id: 'confirmations.logout.confirm', defaultMessage: 'Log out' },
});

const mapDispatchToProps = (dispatch, { intl }) => ({
  onLogout () {
    dispatch(openModal('CONFIRM', {
      message: intl.formatMessage(messages.logoutMessage),
      confirm: intl.formatMessage(messages.logoutConfirm),
      onConfirm: () => logOut(),
    }));
  },
});

export default @injectIntl
@connect(null, mapDispatchToProps)
class LinkFooter extends React.PureComponent {

  static propTypes = {
    withHotkeys: PropTypes.bool,
    onLogout: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  handleLogoutClick = e => {
    e.preventDefault();
    e.stopPropagation();

    this.props.onLogout();

    return false;
  }

  render () {
    const { withHotkeys } = this.props;

    return (
      <div className='getting-started__footer'>
        <ul>
          <li><a href='/about/more' target='_blank'>About us</a> · </li>
          <li><a href='/about/more#apps-on-mobile' target='_blank'><FormattedMessage id='navigation_bar.apps' defaultMessage='Mobile apps' /></a> · </li>
          <li><a href='https://docs.joinmastodon.org' target='_blank'><FormattedMessage id='getting_started.documentation' defaultMessage='Documentation' /></a> · </li>
          <li><a href='/auth/sign_out' onClick={this.handleLogoutClick}><FormattedMessage id='navigation_bar.logout' defaultMessage='Logout' /></a></li>
        </ul>

        <p>
          <span>Logo by Landon Whittaker</span><br/>
          <FormattedMessage
            id='getting_started.queerhaus_open_source_notice'
            defaultMessage='we are open source {github}'
            values={{ github: <span><a href={source_url} rel='noopener noreferrer' target='_blank'>{repository}</a></span> }}
          />
        </p>
      </div>
    );
  }

};
