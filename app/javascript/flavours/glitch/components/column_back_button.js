import React from 'react';
import { FormattedMessage } from 'react-intl';
import PropTypes from 'prop-types';
import Icon from 'flavours/glitch/components/icon';
import { createPortal } from 'react-dom';

export default class ColumnBackButton extends React.PureComponent {

  static contextTypes = {
    router: PropTypes.object,
  };

  static propTypes = {
    multiColumn: PropTypes.bool,
  };

  handleClick = (event) => {
    // if history is exhausted, or we would leave mastodon, just go to root.
    if (window.history.state) {
      const state = this.context.router.history.location.state;
      if (event.shiftKey && state && state.mastodonBackSteps) {
        this.context.router.history.go(-state.mastodonBackSteps);
      } else {
        this.context.router.history.goBack();
      }
    } else {
      this.context.router.history.push('/');
    }
  }

  render () {
    const { multiColumn } = this.props;

    const component = (
      <button onClick={this.handleClick} className='column-back-button'>
        <Icon id='chevron-left' className='column-back-button__icon' fixedWidth />
        <FormattedMessage id='column_back_button.label' defaultMessage='Back' />
      </button>
    );

    if (multiColumn) {
      return component;
    } else {
      return createPortal(component, document.getElementById('tabs-bar__portal'));
    }
  }

}
