import type { Hex } from 'viem';

import type { ApprovalModel } from './approvalTypes';

export type ApprovalRequestSource =
  | 'local'
  | 'agent'
  | 'sdk';

export type ApprovalRequestStatus =
  | 'pending'
  | 'signing'
  | 'signed'
  | 'rejected'
  | 'expired';

export type ApprovalRequest = {
  id: string;

  source: ApprovalRequestSource;
  status: ApprovalRequestStatus;

  title: string;
  description?: string;

  createdAt: number;
  expiresAt: number;

  approval: ApprovalModel;

  signature?: Hex;
  signedAt?: number;
};

export type CreateApprovalRequestInput = {
  id?: string;

  source?: ApprovalRequestSource;

  title: string;
  description?: string;

  expiresAt: number;

  approval: ApprovalModel;
};
